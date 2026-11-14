import qs
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls

Scope {
    id: root

    property bool open: false
    property string popupMode: "mini"
    property var anchorItem
    property var results: []
    property var queue: []
    property var libraryItems: libraryStore.items
    property var quickPicks: quickPickStore.tracks
    property var homeMixes: quickPickStore.mixes
    property bool libraryCacheReady: false
    property bool homeCacheReady: false
    property bool sessionCacheReady: false
    property var playlistTracks: []
    property var currentCollection: null
    property string nextPageToken: ""
    property var currentTrack: null
    property int queueIndex: -1
    property string searchText: ""
    property string searchType: "songs"
    property string page: "home"
    property string apiOperation: ""
    property string apiTrackId: ""
    property var likedIds: ({})
    property string selectedBrowser: musicPreferences.browser
    property string statusText: "Search YouTube Music"
    property real position: 0
    property real duration: 0
    property bool playing: false
    property bool shuffleEnabled: false
    property int repeatMode: 0
    property real volumeLevel: 70
    property bool muted: false
    property string pendingUrl: ""
    // mpv reports pause=false while idle, so only trust the pause property
    // once a file has actually been loaded into the player.
    property bool fileLoaded: false
    property bool trackLoading: false
    property string loadingStage: "idle"
    property string collectionOrigin: "home"
    property bool searchQueued: false
    property bool autoplay: true
    property bool radioPending: false
    property var pendingRequests: []
    property var lyricsLines: []
    property string lyricsState: "idle"
    property string lyricsTrackId: ""
    property string lyricsPendingId: ""
    property bool lyricsWanted: false
    property bool lyricsRetry: false
    property string lyricsMode: "original"
    property var lyricsAlt: []
    property string lyricsAltState: "idle"
    property string lyricsAltFor: ""
    property bool lyricsAltRetry: false
    readonly property string translateScript: Quickshell.shellPath("bar/ytmusic-translate.py")
    property int failStreak: 0
    property string retryTrackId: ""
    property double closedAt: 0
    property string closedMode: ""
    readonly property bool listLoading: apiProcess.running && page !== "queue"
    readonly property string lyricsScript: Quickshell.shellPath("bar/ytmusic-lyrics.sh")
    property string activeSearchQuery: ""
    property var cavaBars: []
    property bool cavaAvailable: false
    readonly property int cavaBarCount: 14
    readonly property string cavaConfigPath: Quickshell.shellPath("bar/cava.conf")
    property int popupCloseDelay: 450
    property bool holdPopup: false
    // A previous Quickshell/mpv crash can leave its Unix socket behind. Use a
    // per-instance path so mpv never gets stuck trying to bind that stale socket.
    // Stable per-config socket name so config reloads reuse one file instead of
    // leaving a stale socket behind on every reload.
    readonly property string ipcPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
        + "/quickshell-ytmusic-" + Quickshell.shellId + ".sock"
    readonly property string apiScript: Quickshell.shellPath("bar/ytmusic-api.sh")
    readonly property string cookiePath: Quickshell.cachePath("ytmusic/" + selectedBrowser + "-cookies.txt")
    readonly property var innerTubeContext: ({
        context: { client: { clientName: "WEB_REMIX", clientVersion: "1.20240813.01.00", hl: "en" } }
    })

    onQueueChanged: saveSession()
    onQueueIndexChanged: saveSession()
    onLyricsLinesChanged: {
        lyricsAlt = []
        lyricsAltState = "idle"
        if (lyricsMode !== "original" && lyricsLines.length > 0) requestLyricsAlt()
    }

    onCurrentTrackChanged: {
        saveSession()
        lyricsTrackId = ""
        lyricsLines = []
        lyricsState = "idle"
        if (lyricsWanted) requestLyrics()
    }
    onVolumeLevelChanged: saveSession()
    onMutedChanged: saveSession()
    onPlayingChanged: updateCava()
    onCavaAvailableChanged: updateCava()

    readonly property var browserOptions: [
        { label: "Vivaldi", value: "vivaldi" },
        { label: "Firefox", value: "firefox" },
        { label: "Chromium", value: "chromium" },
        { label: "Chrome", value: "chrome" },
        { label: "Brave", value: "brave" },
        { label: "Edge", value: "edge" },
        { label: "Opera", value: "opera" }
    ]

    onSelectedBrowserChanged: {
        libraryCacheReady = false
        homeCacheReady = false
    }

    FileView {
        id: musicPreferencesFile
        path: Quickshell.statePath("ytmusic-preferences.json")
        JsonAdapter {
            id: musicPreferences
            property string browser: "vivaldi"
        }
        onAdapterUpdated: writeAdapter()
    }

    FileView {
        id: libraryCacheFile
        path: Quickshell.statePath("ytmusic-library-" + root.selectedBrowser + ".json")
        JsonAdapter {
            id: libraryStore
            property var items: []
        }
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root.libraryCacheReady = true
            if (root.open && root.popupMode === "full" && root.page === "library") {
                if (root.libraryItems.length === 0) root.fetchLibrary(false)
                else root.statusText = "Your saved library · refresh to sync"
            }
        }
        onLoadFailed: {
            root.libraryCacheReady = true
            if (root.open && root.popupMode === "full" && root.page === "library") root.fetchLibrary(false)
        }
    }

    FileView {
        id: homeCacheFile
        path: Quickshell.statePath("ytmusic-home-" + root.selectedBrowser + ".json")
        JsonAdapter {
            id: quickPickStore
            property var tracks: []
            property var mixes: []
        }
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root.homeCacheReady = true
            if (root.open && root.popupMode === "full" && root.page === "home") {
                if (root.quickPicks.length + root.homeMixes.length === 0) root.fetchHome(false)
                else root.statusText = "Quick picks · refresh to update"
            }
        }
        onLoadFailed: {
            root.homeCacheReady = true
            if (root.open && root.popupMode === "full" && root.page === "home") root.fetchHome(false)
        }
    }

    FileView {
        id: sessionCacheFile
        path: Quickshell.statePath("ytmusic-session.json")
        JsonAdapter {
            id: sessionStore
            property var queue: []
            property int queueIndex: -1
            property var currentTrack: null
            property real volume: 70
            property bool muted: false
        }
        onAdapterUpdated: sessionSaveTimer.restart()
        onLoaded: {
            root.sessionCacheReady = true
            root.volumeLevel = sessionStore.volume
            root.muted = sessionStore.muted
            if (sessionStore.queue.length > 0) {
                root.queue = sessionStore.queue
                root.queueIndex = sessionStore.queueIndex
                root.currentTrack = sessionStore.currentTrack
                root.statusText = "Queue restored · press play to resume"
            }
        }
        onLoadFailed: root.sessionCacheReady = true
    }

    function browserLabel(value: string): string {
        const item = browserOptions.find(function(option) { return option.value === value })
        return item ? item.label : "Vivaldi"
    }

    function browserCommand(value: string): string {
        const commands = {
            vivaldi: "vivaldi",
            firefox: "firefox",
            chromium: "chromium",
            chrome: "google-chrome-stable",
            brave: "brave-browser",
            edge: "microsoft-edge-stable",
            opera: "opera"
        }
        return commands[value] || "vivaldi"
    }

    function openMusicSite(): void {
        browserProcess.exec([browserCommand(selectedBrowser), "https://music.youtube.com"])
        statusText = "Opened YouTube Music in " + browserLabel(selectedBrowser)
    }

    // Popups close on a click outside, Esc, or clicking the capsule again.
    // There is no hover-to-stay timer anymore.
    function closePopup(): void {
        if (holdPopup || !open) return
        closedMode = popupMode
        closedAt = Date.now()
        open = false
    }

    // The focus grab clears (and closes the popup) just before the capsule click
    // arrives, so ignore a toggle that lands right after a close of the same mode.
    function justClosed(mode: string): bool {
        return !open && closedMode === mode && Date.now() - closedAt < 300
    }

    function toggleMini(): void {
        if (open && popupMode === "mini") { closePopup(); return }
        if (justClosed("mini")) return
        popupMode = "mini"
        open = true
        // Warm up mpv while the user looks around so playback starts instantly.
        startPlayer()
    }

    function openLibrary(targetPage: string): void {
        page = targetPage || "home"
        popupMode = "full"
        open = true
        startPlayer()
        if (page === "home") {
            if (!homeCacheReady) statusText = "Restoring quick picks…"
            else if (quickPicks.length + homeMixes.length === 0) fetchHome(false)
            else statusText = "Quick picks · refresh to update"
        }
    }

    function toggleFull(): void {
        if (open && popupMode === "full") { closePopup(); return }
        if (justClosed("full")) return
        openLibrary("home")
    }

    function nudgeVolume(delta): void {
        setPlayerVolume(volumeLevel + delta)
    }

    // ---------- lyrics (lrclib.net, no key) ----------
    function parseLrc(text): var {
        const out = []
        for (const raw of String(text).split("\n")) {
            const m = raw.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/)
            if (m) out.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3] || "♪" })
        }
        return out
    }

    function setLyricsMode(mode: string): void {
        lyricsMode = mode
        lyricsAlt = []
        lyricsAltState = "idle"
        if (mode !== "original") requestLyricsAlt()
    }

    function requestLyricsAlt(): void {
        if (lyricsMode === "original" || lyricsLines.length === 0) return
        lyricsAltState = "loading"
        if (translateProc.running) { lyricsAltRetry = true; return }
        const key = lyricsMode === "roman" ? "roman" : "en"
        lyricsAltFor = lyricsTrackId + ":" + key
        translateProc.exec(["python3", translateScript, key,
            JSON.stringify(lyricsLines.map(function(line) { return line.text }))])
    }

    function handleLyricsAlt(text): void {
        const key = lyricsMode === "roman" ? "roman" : "en"
        if (lyricsAltFor !== lyricsTrackId + ":" + key) return
        let data = null
        try { data = JSON.parse(text) } catch (error) { data = null }
        if (Array.isArray(data) && data.length === lyricsLines.length) {
            lyricsAlt = data
            lyricsAltState = "ready"
        } else {
            lyricsAltState = "failed"
        }
    }

    function requestLyrics(): void {
        if (!currentTrack) { lyricsState = "idle"; lyricsLines = []; return }
        if (lyricsTrackId === currentTrack.id && lyricsState !== "idle") return
        lyricsTrackId = currentTrack.id
        lyricsLines = []
        lyricsState = "loading"
        if (lyricsProc.running) { lyricsRetry = true; return }
        lyricsPendingId = currentTrack.id
        const title = String(currentTrack.title || "")
            .replace(/\s*[\(\[][^\)\]]*[\)\]]/g, "").replace(/\s+-\s+.*$/, "").trim() || String(currentTrack.title || "")
        const artist = String(currentTrack.artist || "").split(/[,&·]/)[0].replace(/\s*-\s*topic$/i, "").trim()
        lyricsProc.exec(["bash", lyricsScript, title, artist, String(Math.round(currentTrack.duration || 0))])
    }

    function handleLyrics(text): void {
        if (!currentTrack || currentTrack.id !== lyricsPendingId) return
        let data = null
        try { data = JSON.parse(text) } catch (error) { data = null }
        if (Array.isArray(data)) {
            let pick = data.find(function(item) { return item && item.syncedLyrics })
            if (!pick) pick = data.find(function(item) { return item && item.plainLyrics })
            data = pick || null
        }
        if (data && data.syncedLyrics) {
            const parsed = parseLrc(data.syncedLyrics)
            if (parsed.length > 0) { lyricsLines = parsed; lyricsState = "ready"; return }
        }
        if (data && data.plainLyrics) {
            lyricsLines = String(data.plainLyrics).split("\n").map(function(line) { return { t: -1, text: line } })
            lyricsState = "plain"
            return
        }
        lyricsLines = []
        lyricsState = "none"
    }

    function runNextRequest(): void {
        if (apiProcess.running || pendingRequests.length === 0) return
        const next = pendingRequests[0]
        pendingRequests = pendingRequests.slice(1)
        requestApi(next.endpoint, next.payload, next.operation, next.message)
    }

    function requestApi(endpoint: string, payload, operation: string, message: string): void {
        if (apiProcess.running) {
            if (pendingRequests.length < 6)
                pendingRequests = pendingRequests.concat([{ endpoint: endpoint, payload: payload, operation: operation, message: message }])
            return
        }
        apiOperation = operation
        statusText = message
        apiProcess.exec(["bash", apiScript, "api", cookiePath, endpoint, JSON.stringify(payload)])
    }

    function toggleLike(): void {
        if (!currentTrack || !currentTrack.id || apiProcess.running) return
        apiTrackId = currentTrack.id
        const liked = likedIds[apiTrackId] === true
        const request = Object.assign({}, innerTubeContext, { target: { videoId: apiTrackId } })
        requestApi(liked ? "like/removelike" : "like/like", request, liked ? "unlike" : "like", liked ? "Removing like…" : "Liking track…")
    }

    function toggleShuffle(): void { shuffleEnabled = !shuffleEnabled }
    function cycleRepeat(): void { repeatMode = (repeatMode + 1) % 3 }

    function setPlayerVolume(value): void {
        volumeLevel = Math.max(0, Math.min(100, Number(value) || 0))
        sendMpv(["set_property", "volume", volumeLevel])
    }

    function fetchLibrary(refresh: bool): void {
        page = "library"
        if (!refresh && libraryItems.length > 0) {
            statusText = "Your library · refresh to sync"
            return
        }
        const request = Object.assign({}, innerTubeContext, { browseId: "FEmusic_library_landing" })
        requestApi("browse", request, "library", "Loading your YouTube Music library…")
    }

    function fetchHome(refresh: bool): void {
        page = "home"
        if (!refresh && quickPicks.length + homeMixes.length > 0) {
            statusText = "Quick picks · refresh to update"
            return
        }
        const request = Object.assign({}, innerTubeContext, { browseId: "FEmusic_home" })
        requestApi("browse", request, "home", "Loading YouTube Music recommendations…")
    }

    function fetchRadio(): void {
        if (!currentTrack || !currentTrack.id) { radioPending = false; return }
        const id = currentTrack.id
        const request = Object.assign({}, innerTubeContext, {
            videoId: id, playlistId: "RDAMVM" + id, params: "wAEB", isAudioOnly: true
        })
        requestApi("next", request, "radio", "Finding similar tracks…")
    }

    function syncLikes(): void {
        const request = Object.assign({}, innerTubeContext, { browseId: "VLLM" })
        requestApi("browse", request, "likes", "Syncing liked songs…")
    }

    function openCollection(collection): void {
        searchDebounce.stop()
        if (page !== "collection") collectionOrigin = page
        currentCollection = collection
        playlistTracks = []
        nextPageToken = ""
        page = "collection"
        const request = Object.assign({}, innerTubeContext, { browseId: collection.id })
        requestApi("browse", request, "collection", "Loading " + collection.title + "…")
    }

    function fetchMoreTracks(): void {
        if (!nextPageToken || apiProcess.running) return
        const request = Object.assign({}, innerTubeContext, { continuation: nextPageToken })
        requestApi("browse", request, "moreTracks", "Loading more tracks…")
    }

    function textValue(value): string {
        if (typeof value === "string") return value
        if (!value) return ""
        if (value.simpleText) return value.simpleText
        if (Array.isArray(value.runs)) return value.runs.map(function(run) { return run.text || "" }).join("")
        return ""
    }

    function thumbnailValue(value): string {
        if (!value) return ""
        const thumb = value.musicThumbnailRenderer && value.musicThumbnailRenderer.thumbnail
            ? value.musicThumbnailRenderer.thumbnail
            : value.thumbnail && value.thumbnail.thumbnails ? value.thumbnail : value
        const thumbnails = thumb.thumbnails || []
        return thumbnails.length ? thumbnails[thumbnails.length - 1].url || "" : ""
    }

    function parseDurationText(value): int {
        const match = String(value || "").match(/(\d+):([0-5]\d)\s*$/)
        return match ? Number(match[1]) * 60 + Number(match[2]) : 0
    }

    function browsePageType(run): string {
        const endpoint = run && run.navigationEndpoint && run.navigationEndpoint.browseEndpoint
        return endpoint && endpoint.browseEndpointContextSupportedConfigs
            && endpoint.browseEndpointContextSupportedConfigs.browseEndpointContextMusicConfig
            && endpoint.browseEndpointContextSupportedConfigs.browseEndpointContextMusicConfig.pageType || ""
    }

    function runsTextForPageType(column, pageType): string {
        const runs = column && column.runs ? column.runs : []
        return runs.filter(function(run) { return browsePageType(run) === pageType })
            .map(function(run) { return run.text || "" }).join("")
    }

    function collectApiItems(data, allowedKinds): var {
        const items = []
        const seen = {}
        function add(id, kind, title, artist, thumbnail, duration, album) {
            if (!id || !title || (allowedKinds && allowedKinds.indexOf(kind) < 0)) return
            const key = kind + ":" + id
            if (seen[key]) return
            seen[key] = true
            items.push({
                id: id, kind: kind, title: title, artist: artist || "", album: album || "",
                duration: Number(duration) || 0,
                thumbnail: thumbnail || (kind === "song" ? "https://i.ytimg.com/vi/" + id + "/hqdefault.jpg" : ""),
                url: "https://music.youtube.com/watch?v=" + id
            })
        }
        function visit(node) {
            if (!node || typeof node !== "object") return
            if (Array.isArray(node)) {
                for (const child of node) visit(child)
                return
            }
            const row = node.musicResponsiveListItemRenderer
            if (row) {
                const columns = row.flexColumns || []
                const firstColumn = columns.length && columns[0].musicResponsiveListItemFlexColumnRenderer
                    ? columns[0].musicResponsiveListItemFlexColumnRenderer.text : null
                const secondColumn = columns.length > 1 && columns[1].musicResponsiveListItemFlexColumnRenderer
                    ? columns[1].musicResponsiveListItemFlexColumnRenderer.text : null
                const thirdColumn = columns.length > 2 && columns[2].musicResponsiveListItemFlexColumnRenderer
                    ? columns[2].musicResponsiveListItemFlexColumnRenderer.text : null
                const secondText = textValue(secondColumn)
                const title = textValue(firstColumn)
                const videoId = (row.playlistItemData && row.playlistItemData.videoId)
                    || (row.navigationEndpoint && row.navigationEndpoint.watchEndpoint && row.navigationEndpoint.watchEndpoint.videoId)
                const endpoint = row.navigationEndpoint && row.navigationEndpoint.browseEndpoint
                const browseId = endpoint && endpoint.browseId
                let kind = "song"
                if (!videoId && browseId) {
                    const pageType = endpoint.browseEndpointContextSupportedConfigs
                        && endpoint.browseEndpointContextSupportedConfigs.browseEndpointContextMusicConfig
                        && endpoint.browseEndpointContextSupportedConfigs.browseEndpointContextMusicConfig.pageType
                    kind = pageType === "MUSIC_PAGE_TYPE_ALBUM" ? "album"
                        : pageType === "MUSIC_PAGE_TYPE_ARTIST" ? "artist" : "playlist"
                }
                const artist = kind === "song" ? secondText.split(" • ")[0].trim() : secondText
                const album = runsTextForPageType(thirdColumn, "MUSIC_PAGE_TYPE_ALBUM")
                    || runsTextForPageType(secondColumn, "MUSIC_PAGE_TYPE_ALBUM")
                const fixed = row.fixedColumns && row.fixedColumns.length
                    ? textValue(row.fixedColumns[0].musicResponsiveListItemFixedColumnRenderer.text) : ""
                const seconds = parseDurationText(secondText) || parseDurationText(fixed)
                const thumb = thumbnailValue(row.thumbnail || row.thumbnailRenderer)
                if (videoId) add(videoId, "song", title, artist, thumb, seconds, album)
                else if (browseId) add(browseId, kind, title, artist, thumb, 0, album)
            }
            const panel = node.playlistPanelVideoRenderer
            if (panel && panel.videoId) {
                const byline = panel.shortBylineText || panel.longBylineText
                const bylineRuns = byline && byline.runs ? byline.runs : []
                add(panel.videoId, "song", textValue(panel.title), bylineRuns.length ? bylineRuns[0].text : "",
                    thumbnailValue(panel.thumbnail), parseDurationText(textValue(panel.lengthText)), "")
            }
            const card = node.musicTwoRowItemRenderer
            if (card) {
                const title = textValue(card.title)
                const subtitle = textValue(card.subtitle)
                const endpoint = card.navigationEndpoint && card.navigationEndpoint.browseEndpoint
                const titleEndpoint = card.title && card.title.runs && card.title.runs.length
                    ? card.title.runs[0].navigationEndpoint && card.title.runs[0].navigationEndpoint.browseEndpoint : null
                const browseId = (endpoint && endpoint.browseId) || (titleEndpoint && titleEndpoint.browseId)
                const pageTypeSource = endpoint || titleEndpoint
                const pageType = pageTypeSource && pageTypeSource.browseEndpointContextSupportedConfigs
                    && pageTypeSource.browseEndpointContextSupportedConfigs.browseEndpointContextMusicConfig
                    && pageTypeSource.browseEndpointContextSupportedConfigs.browseEndpointContextMusicConfig.pageType
                const kind = pageType === "MUSIC_PAGE_TYPE_ALBUM" ? "album"
                    : pageType === "MUSIC_PAGE_TYPE_ARTIST" ? "artist" : "playlist"
                add(browseId, kind, title, subtitle, thumbnailValue(card.thumbnailRenderer), 0, "")
            }
            for (const key of Object.keys(node)) visit(node[key])
        }
        visit(data)
        return items
    }

    function continuationFrom(data): string {
        let token = ""
        function visit(node) {
            if (!node || typeof node !== "object" || token) return
            if (Array.isArray(node)) {
                for (const child of node) visit(child)
                return
            }
            if (node.continuationCommand && node.continuationCommand.token)
                token = node.continuationCommand.token
            else if (node.nextContinuationData && node.nextContinuationData.continuation)
                token = node.nextContinuationData.continuation
            else for (const key of Object.keys(node)) visit(node[key])
        }
        visit(data)
        return token
    }

    function handleApiResponse(output: string): void {
        if (apiOperation === "like" || apiOperation === "unlike") {
            const updatedLikes = Object.assign({}, likedIds)
            if (apiOperation === "like") updatedLikes[apiTrackId] = true
            else delete updatedLikes[apiTrackId]
            likedIds = updatedLikes
            statusText = apiOperation === "like" ? "Added to liked songs" : "Removed from liked songs"
            return
        }
        try {
            const data = JSON.parse(output)
            const items = collectApiItems(data, null)
            if (apiOperation === "library") {
                const collections = items.filter(function(item) { return item.kind !== "song" })
                libraryStore.items = collections
                statusText = collections.length ? "Library updated · " + collections.length + " collections" : "No library items found"
                syncLikes()
            } else if (apiOperation === "home") {
                const tracks = items.filter(function(item) { return item.kind === "song" })
                const mixes = items.filter(function(item) { return item.kind !== "song" })
                quickPickStore.tracks = tracks
                quickPickStore.mixes = mixes
                statusText = tracks.length + " quick picks · " + mixes.length + " mixes"
            } else if (apiOperation === "likes") {
                const synced = Object.assign({}, likedIds)
                for (const track of items) if (track.kind === "song") synced[track.id] = true
                likedIds = synced
            } else if (apiOperation === "radio") {
                const known = {}
                for (const queued of queue) known[queued.id] = true
                const fresh = items.filter(function(item) { return item.kind === "song" && !known[item.id] })
                if (fresh.length > 0) {
                    queue = queue.concat(fresh)
                    statusText = "Autoplay · " + fresh.length + " similar tracks added"
                    if (radioPending) {
                        radioPending = false
                        playQueueItem(queueIndex + 1)
                    }
                } else {
                    radioPending = false
                    playing = false
                    position = 0
                    statusText = "Queue finished"
                }
            } else if (apiOperation === "collection") {
                playlistTracks = items.filter(function(item) { return item.kind === "song" })
                if (root.currentCollection && root.currentCollection.id === "VLLM") {
                    const updatedLikes = Object.assign({}, likedIds)
                    for (const track of playlistTracks) updatedLikes[track.id] = true
                    likedIds = updatedLikes
                }
                nextPageToken = continuationFrom(data)
                statusText = playlistTracks.length ? "Tap a track to play · + to queue" : "No tracks found in this collection"
            } else if (apiOperation === "moreTracks") {
                playlistTracks = playlistTracks.concat(items.filter(function(item) { return item.kind === "song" }))
                nextPageToken = continuationFrom(data)
                statusText = "Loaded " + playlistTracks.length + " tracks"
            } else if (apiOperation === "search") {
                // Ignore a response for a query the user has already changed.
                if (root.activeSearchQuery !== root.searchText.trim()) return
                results = items.filter(function(item) {
                    return root.searchType === "playlists" ? item.kind === "playlist"
                        : root.searchType === "albums" ? item.kind === "album" : item.kind === "song"
                })
                statusText = results.length ? "Tap a result to open or play · + to queue" : "No results found"
            }
        } catch (error) {
            if (radioPending) { radioPending = false; playing = false; position = 0 }
            statusText = "Could not read YouTube Music data. Try reconnecting your browser."
        }
    }

    function connectAccount(): void {
        statusText = "Connecting with " + browserLabel(selectedBrowser) + "…"
        authProcess.exec(["bash", apiScript, "extract-cookies", selectedBrowser, cookiePath])
    }

    function saveSession(): void {
        if (!sessionCacheReady) return
        sessionStore.queue = queue
        sessionStore.queueIndex = queueIndex
        sessionStore.currentTrack = currentTrack
        sessionStore.volume = volumeLevel
        sessionStore.muted = muted
    }

    function togglePlayback(): void {
        if (!playerProcess.running || !mpvSocket.connected) {
            if (queueIndex >= 0 && queueIndex < queue.length) playQueueItem(queueIndex)
            else if (currentTrack) addTrack(currentTrack, true)
            else if (queue.length > 0) playQueueItem(0)
            return
        }
        // mpv stays connected but idle after a track ends or an error. There is
        // nothing to un-pause then, so reload the track instead.
        if (!fileLoaded && !trackLoading) {
            if (queueIndex >= 0 && queueIndex < queue.length) playQueueItem(queueIndex)
            else if (queue.length > 0) playQueueItem(0)
            return
        }
        sendMpv(["cycle", "pause"])
    }

    function holdOpen(): void {
        popupCloseTimer.stop()
    }

    function scheduleClose(): void {
        if (open) popupCloseTimer.restart()
    }

    function formatTime(value): string {
        const seconds = Math.max(0, Math.floor(Number(value) || 0))
        const minutes = Math.floor(seconds / 60)
        const remainder = seconds % 60
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
    }

    function isCurrentTrack(item): bool {
        return !!(item && item.id && root.currentTrack && item.id === root.currentTrack.id)
    }

    function actionGlyph(item): string {
        if (root.page === "queue") return "−"
        if (root.page === "library" || item.kind !== "song") return "›"
        return "+"
    }

    function pageTitle(): string {
        if (root.page === "home") return "Home"
        if (root.page === "library") return "Library"
        if (root.page === "search") return "Search"
        if (root.page === "queue") return "Queue"
        return root.currentCollection ? root.currentCollection.title : "Collection"
    }

    function pageCount(): int {
        if (root.page === "home") return root.quickPicks.length + root.homeMixes.length
        if (root.page === "library") return root.libraryItems.length
        if (root.page === "collection") return root.playlistTracks.length
        if (root.page === "queue") return root.queue.length
        return root.results.length
    }

    function listModel(): var {
        if (root.page === "home") {
            const model = []
            if (root.quickPicks.length > 0) model.push({ header: "Quick picks" })
            for (const track of root.quickPicks) model.push(track)
            if (root.homeMixes.length > 0) model.push({ header: "Mixes for you" })
            for (const mix of root.homeMixes) model.push(mix)
            return model
        }
        if (root.page === "library") {
            const playlists = root.libraryItems.filter(function(item) { return item.kind === "playlist" })
            const others = root.libraryItems.filter(function(item) { return item.kind !== "playlist" && item.kind !== "artist" })
            const artists = root.libraryItems.filter(function(item) { return item.kind === "artist" })
            const model = []
            if (playlists.length > 0) model.push({ header: "Playlists" })
            for (const item of playlists) model.push(item)
            if (others.length > 0) model.push({ header: "Albums & more" })
            for (const item of others) model.push(item)
            if (artists.length > 0) model.push({ header: "Artists" })
            for (const item of artists) model.push(item)
            return model
        }
        if (root.page === "collection") return root.playlistTracks
        if (root.page === "queue") return root.queue
        return root.results
    }

    function emptyMessage(): string {
        if (apiProcess.running) return "Loading…"
        if (root.page === "search") return root.searchText.trim() ? "No results found" : "Type to search YouTube Music"
        if (root.page === "library") return "Your library is empty · press refresh to sync"
        if (root.page === "home") return "Nothing here yet · press refresh"
        if (root.page === "queue") return "Queue is empty · add songs to get started"
        return "No tracks in this collection"
    }

    // Search is reactive: typing restarts a short debounce so a burst of
    // keystrokes only produces one API request.
    function scheduleSearch(): void {
        searchDebounce.restart()
    }

    function searchNow(): void {
        searchDebounce.stop()
        performSearch()
    }

    function performSearch(): void {
        const query = searchText.trim()
        if (!query) {
            results = []
            activeSearchQuery = ""
            searchQueued = false
            statusText = "Type to search YouTube Music"
            return
        }
        if (apiProcess.running) {
            // A request is in flight; run this query as soon as it finishes.
            searchQueued = true
            return
        }
        searchQueued = false
        page = "search"
        statusText = "Searching…"
        activeSearchQuery = query
        const params = searchType === "songs" ? "EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D"
            : searchType === "playlists" ? "EgeKAQQoADgBKAI6AklTUAFQBRAFEAkQBA%3D%3D"
            : "EgWKAQIYAWoKEAkQBRAKEAMQBA%3D%3D"
        const request = Object.assign({}, innerTubeContext, { query: query, params: params })
        requestApi("search", request, "search", "Searching YouTube Music…")
    }

    function startPlayer(): void {
        if (!playerProcess.running) playerProcess.running = true
    }

    function updateCava(): void {
        cavaProcess.running = root.playing && root.cavaAvailable
    }

    function sendMpv(command): void {
        if (!mpvSocket.connected) return
        mpvSocket.write(JSON.stringify({ command: command }) + "\n")
        mpvSocket.flush()
    }

    function playTrack(track, index: int): void {
        if (!track || !track.url) return
        currentTrack = track
        queueIndex = index
        position = 0
        duration = track.duration || 0
        fileLoaded = false
        trackLoading = true
        loadingStage = "resolve"
        startPlayer()
        statusText = "Finding stream…"
        loadTimeout.restart()
        // Hand the watch URL to mpv and let its yt-dlp integration resolve the
        // stream. Fetching the raw googlevideo URL with yt-dlp and passing it to
        // ffmpeg returns HTTP 403, so mpv has to drive yt-dlp itself.
        if (mpvSocket.connected) {
            sendMpv(["loadfile", track.url, "replace"])
            pendingUrl = ""
        } else {
            pendingUrl = track.url
        }
    }

    // Clicking a song plays it right away and slots it after the current
    // track (YouTube Music's "play next"), instead of dumping it at the end.
    function addTrack(track, playNow: bool): void {
        const updated = queue.slice()
        let current = queueIndex
        const existing = updated.findIndex(function(item) { return item.id === track.id })
        if (existing >= 0 && existing === current) {
            if (playNow) playQueueItem(current)
            return
        }
        if (existing >= 0) {
            updated.splice(existing, 1)
            if (existing < current) current -= 1
        }
        const at = current >= 0 ? current + 1 : updated.length
        updated.splice(at, 0, track)
        queueIndex = current
        queue = updated
        if (playNow || current < 0) playTrack(track, at)
        else statusText = "Playing next · " + (track.title || "track")
    }

    function addTrackEnd(track): void {
        if (queue.some(function(item) { return item.id === track.id })) {
            statusText = "Already in the queue"
            return
        }
        const updated = queue.slice()
        updated.push(track)
        queue = updated
        if (queueIndex < 0) playTrack(track, updated.length - 1)
        else statusText = "Added to the end of the queue"
    }


    function playQueueItem(index: int): void {
        if (index < 0 || index >= queue.length) return
        playTrack(queue[index], index)
    }

    function playCollectionAt(index: int): void {
        queue = playlistTracks.slice()
        if (index >= 0 && index < queue.length) playQueueItem(index)
    }

    function removeQueueItem(index: int): void {
        if (index < 0 || index >= queue.length) return
        const updated = queue.slice()
        updated.splice(index, 1)
        queue = updated
        if (index < queueIndex) queueIndex -= 1
        else if (index === queueIndex) {
            if (queueIndex < queue.length) playQueueItem(queueIndex)
            else {
                queueIndex = -1
                currentTrack = null
                fileLoaded = false
                playing = false
                position = 0
                duration = 0
                loadTimeout.stop()
                sendMpv(["stop"])
            }
        }
    }

    function clearQueue(): void {
        if (queue.length === 0) return
        queue = []
        queueIndex = -1
        currentTrack = null
        fileLoaded = false
        playing = false
        position = 0
        duration = 0
        loadTimeout.stop()
        sendMpv(["stop"])
        statusText = "Queue cleared"
    }

    function moveQueueItem(from: int, to: int): void {
        if (from === to) return
        if (from < 0 || to < 0 || from >= queue.length || to >= queue.length) return
        const updated = queue.slice()
        const item = updated.splice(from, 1)[0]
        updated.splice(to, 0, item)
        if (queueIndex === from) queueIndex = to
        else if (from < queueIndex && queueIndex <= to) queueIndex -= 1
        else if (to <= queueIndex && queueIndex < from) queueIndex += 1
        queue = updated
    }

    function activatePanelItem(item, index: int): void {
        if (page === "home") {
            if (item.kind === "song") addTrack(item, true)
            else openCollection(item)
        } else if (page === "library") openCollection(item)
        else if (page === "collection") playCollectionAt(index)
        else if (page === "queue") playQueueItem(index)
        else if (page === "search") {
            if (item.kind === "song") addTrack(item, true)
            else openCollection(item)
        }
    }

    function hasNextTrack(): bool {
        if (queue.length === 0) return false
        if (repeatMode === 2) return true
        if (shuffleEnabled && queue.length > 1) return true
        if (queueIndex + 1 < queue.length) return true
        if (repeatMode === 1) return true
        return false
    }

    function nextTrack(): void {
        if (queue.length === 0) return
        if (repeatMode === 2 && queueIndex >= 0) {
            sendMpv(["set_property", "time-pos", 0])
            sendMpv(["set_property", "pause", false])
        } else if (shuffleEnabled && queue.length > 1) {
            let index = Math.floor(Math.random() * queue.length)
            if (index === queueIndex) index = (index + 1) % queue.length
            playQueueItem(index)
        } else if (queueIndex + 1 < queue.length) playQueueItem(queueIndex + 1)
        else if (repeatMode === 1) playQueueItem(0)
    }

    function previousTrack(): void {
        if (position > 4) sendMpv(["set_property", "time-pos", 0])
        else if (queueIndex > 0) playQueueItem(queueIndex - 1)
        else if (queueIndex === 0 && repeatMode === 1 && queue.length > 0) playQueueItem(queue.length - 1)
    }

    function handleMessage(line: string): void {
        try {
            const message = JSON.parse(line)
            if (message.event === "property-change") {
                if (message.name === "time-pos") position = Number(message.data) || 0
                else if (message.name === "duration") duration = Number(message.data) || 0
                else if (message.name === "pause") { if (fileLoaded) playing = !message.data }
                else if (message.name === "volume") volumeLevel = Number(message.data) || 0
                else if (message.name === "mute") muted = Boolean(message.data)
            } else if (message.event === "file-loaded") {
                loadTimeout.stop()
                fileLoaded = true
                playing = true
                trackLoading = false
                loadingStage = "idle"
                statusText = "Playing from YouTube Music"
                failStreak = 0
                retryTrackId = ""
            } else if (message.event === "end-file" && message.reason === "error") {
                loadTimeout.stop()
                fileLoaded = false
                playing = false
                trackLoading = false
                loadingStage = "idle"
                statusText = "Playback failed" + (message.file_error ? " (" + message.file_error + ")" : "") + ". Update yt-dlp and check a JS runtime (deno or node) is installed."
                if (currentTrack && queueIndex >= 0 && retryTrackId !== currentTrack.id) {
                    retryTrackId = currentTrack.id
                    statusText = "yt-dlp hiccuped. Retrying this track once…"
                    failRetryTimer.start()
                } else if (failStreak < 3 && hasNextTrack()) {
                    failStreak += 1
                    statusText = "Could not play that track. Skipping to the next one…"
                    failSkipTimer.start()
                }
            } else if (message.event === "end-file" && message.reason === "eof") {
                fileLoaded = false
                trackLoading = false
                // mpv is idle after eof, so repeat-one must reload the track
                // instead of seeking inside a file that no longer exists.
                if (repeatMode === 2 && queueIndex >= 0) {
                    playQueueItem(queueIndex)
                } else if (hasNextTrack()) {
                    nextTrack()
                } else if (autoplay && currentTrack) {
                    radioPending = true
                    fetchRadio()
                } else {
                    // Nothing left to play: drop out of the "playing" state so the
                    // bar visualizer stops and the capsule collapses.
                    playing = false
                    position = 0
                    statusText = "Queue finished"
                }
            } else if (message.error && message.error !== "success") {
                trackLoading = false
                loadingStage = "idle"
                statusText = "Playback failed. Check yt-dlp or " + browserLabel(selectedBrowser) + " sign-in."
            }
        } catch (error) {
            // Ignore non-JSON socket lines.
        }
    }

    Timer {
        id: popupCloseTimer
        interval: root.popupCloseDelay
        onTriggered: { if (!root.holdPopup) root.open = false }
    }

    Timer {
        id: sessionSaveTimer
        interval: 500
        onTriggered: sessionCacheFile.writeAdapter()
    }

    Timer {
        id: searchDebounce
        interval: 420
        onTriggered: root.performSearch()
    }

    Process {
        id: lyricsProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.handleLyrics(this.text)
        }
        onExited: function(exitCode) {
            if (root.lyricsRetry) {
                root.lyricsRetry = false
                Qt.callLater(function() { root.lyricsTrackId = ""; root.requestLyrics() })
            } else if (root.lyricsState === "loading" && root.currentTrack && root.currentTrack.id === root.lyricsPendingId) {
                root.lyricsState = "none"
            }
        }
    }

    Process {
        id: translateProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.handleLyricsAlt(this.text)
        }
        onExited: function(exitCode) {
            if (root.lyricsAltRetry) {
                root.lyricsAltRetry = false
                Qt.callLater(function() { root.requestLyricsAlt() })
            } else if (exitCode !== 0 && root.lyricsAltState === "loading") {
                root.lyricsAltState = "failed"
            }
        }
    }

    Timer {
        id: failRetryTimer
        interval: 700
        onTriggered: { if (root.queueIndex >= 0) root.playQueueItem(root.queueIndex) }
    }

    Timer {
        id: failSkipTimer
        interval: 900
        onTriggered: root.nextTrack()
    }

    Timer {
        id: loadTimeout
        interval: 20000
        onTriggered: {
            if (!root.trackLoading) return
            root.trackLoading = false
            root.loadingStage = "idle"
            root.statusText = "Still loading. Check network, mpv, or " + root.browserLabel(root.selectedBrowser) + " sign-in."
        }
    }

    Timer {
        id: socketRetry
        interval: 100
        repeat: true
        onTriggered: {
            if (mpvSocket.connected) stop()
            else if (playerProcess.running) {
                // Socket.connected is a target state. Toggle it through false
                // to force a new attempt after mpv has finished binding IPC.
                mpvSocket.connected = false
                Qt.callLater(function() {
                    if (playerProcess.running && !mpvSocket.connected)
                        mpvSocket.connected = true
                })
            }
            else stop()
        }
    }

    Process {
        id: authProcess
        running: false
        stderr: StdioCollector { id: authErrors }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.statusText = "Connected to YouTube Music"
                root.fetchLibrary(true)
            } else {
                const detail = authErrors.text.trim()
                root.statusText = detail || "Could not connect. Sign in to YouTube Music in " + root.browserLabel(root.selectedBrowser) + "."
            }
        }
    }

    Process {
        id: apiProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) root.handleApiResponse(this.text)
            }
        }
        stderr: StdioCollector { id: apiErrors }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                const detail = apiErrors.text.trim()
                root.statusText = detail || "YouTube Music request failed. Reconnect your browser account and try again."
                if (root.radioPending) { root.radioPending = false; root.playing = false; root.position = 0 }
            }
            if (root.pendingRequests.length > 0) {
                Qt.callLater(root.runNextRequest)
            } else if (root.searchQueued) {
                root.searchQueued = false
                Qt.callLater(root.performSearch)
            }
        }
    }

    Process {
        id: browserProcess
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) root.statusText = "Could not open " + root.browserLabel(root.selectedBrowser)
        }
    }

    Process {
        id: cavaCheck
        command: ["sh", "-c", "command -v cava"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.cavaAvailable = this.text.trim().length > 0
        }
    }

    Process {
        id: cavaProcess
        running: false
        command: ["cava", "-p", root.cavaConfigPath]
        stderr: StdioCollector {}
        stdout: SplitParser {
            onRead: function(line) {
                if (!line) return
                const parts = line.split(";")
                const values = []
                for (let i = 0; i < parts.length; i++) values.push(Number(parts[i]) || 0)
                root.cavaBars = values
            }
        }
        onExited: {
            root.cavaBars = []
            // If cava died while it was meant to be running, stop respawning it
            // on every playback change.
            if (root.playing && root.cavaAvailable) root.cavaAvailable = false
        }
    }

    Process {
        id: playerProcess
        // yt-dlp crashes on exit if the cookie folder does not exist, and mpv
        // then reports the stream as failed. Create it before launching.
        command: [
            "bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && exec mpv --no-config --idle=yes --no-video --force-window=no "
                + "--terminal=no --input-ipc-server=\"$2\" --ytdl-format=bestaudio/best --log-file=\"$2.log\" "
                + "--ytdl-raw-options=cookies=\"$1\",extractor-retries=3,retries=5,socket-timeout=15",
            "mpv-launcher", root.cookiePath, root.ipcPath
        ]
        running: false
        onStarted: {
            socketRetry.start()
        }
        onExited: function(exitCode) {
            mpvSocket.connected = false
            root.fileLoaded = false
            root.playing = false
            if (exitCode !== 0) root.statusText = "mpv stopped unexpectedly"
        }
    }

    Socket {
        id: mpvSocket
        path: root.ipcPath
        connected: false
        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root.handleMessage(line) }
        }
        onConnectedChanged: {
            if (!connected) return
            socketRetry.stop()
            root.sendMpv(["observe_property", 1, "time-pos"])
            root.sendMpv(["observe_property", 2, "duration"])
            root.sendMpv(["observe_property", 3, "pause"])
            root.sendMpv(["observe_property", 4, "volume"])
            root.sendMpv(["observe_property", 5, "mute"])
            root.sendMpv(["set_property", "volume", root.volumeLevel])
            root.sendMpv(["set_property", "mute", root.muted])
            if (root.pendingUrl) {
                root.loadingStage = "resolve"
                root.statusText = "Finding stream…"
                loadTimeout.restart()
                root.sendMpv(["loadfile", root.pendingUrl, "replace"])
                root.pendingUrl = ""
            }
        }
        onError: root.statusText = "Could not connect to mpv"
    }

    PopupWindow {
        id: playerPopup
        readonly property bool shown: root.open && root.popupMode === "full"
        visible: shown || fullBody.opacity > 0.01
        anchor.item: root.anchorItem
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        // Change these two numbers to resize the whole library window.
        implicitWidth: 1000
        implicitHeight: 760
        color: "transparent"
        onVisibleChanged: if (visible && root.page === "search") Qt.callLater(function() { searchField.forceActiveFocus() })

        HyprlandFocusGrab {
            active: root.open && root.popupMode === "full"
            windows: [playerPopup]
            onCleared: root.closePopup()
        }

        Rectangle {
            id: fullBody
            focus: true
            Keys.onEscapePressed: root.closePopup()
            anchors.fill: parent
            radius: 18
            opacity: playerPopup.shown ? 1 : 0
            scale: playerPopup.shown ? 1 : 0.96
            transformOrigin: Item.TopRight
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            color: Colors.surfaceContainer
            border.color: Qt.alpha(Colors.outline, 0.4)
            border.width: 1


            // ---------- sidebar ----------
            Rectangle {
                id: sidebar
                property bool browserListOpen: false
                width: 216
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: nowPlaying.top
                anchors.margins: 10
                anchors.bottomMargin: 10
                radius: 14
                color: Colors.surfaceContainerHigh

                Column {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 40
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "♫  YouTube Music"
                            color: Colors.primary
                            font.pixelSize: 15
                            font.bold: true
                        }
                    }

                    Repeater {
                        model: [
                            { id: "player", label: "Now playing", glyph: "♫" },
                            { id: "home", label: "Home", glyph: "⌂" },
                            { id: "library", label: "Library", glyph: "▤" },
                            { id: "search", label: "Search", glyph: "⌕" },
                            { id: "queue", label: "Queue", glyph: "☰" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: root.page === modelData.id
                                || (root.page === "collection" && root.collectionOrigin === modelData.id)
                            width: parent.width
                            height: 40
                            radius: 10
                            color: active ? Qt.alpha(Colors.primary, 0.22)
                                : navArea.containsMouse ? Qt.alpha(Colors.outline, 0.15) : "transparent"
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Text { text: modelData.glyph; color: active ? Colors.primary : Colors.fgDim; font.pixelSize: 16; width: 18; horizontalAlignment: Text.AlignHCenter }
                                Text { text: modelData.label; color: active ? Colors.primary : Colors.fg; font.pixelSize: 13; font.bold: active }
                            }
                            Text {
                                visible: modelData.id === "queue" && root.queue.length > 0
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.queue.length
                                color: Colors.outline
                                font.pixelSize: 11
                            }
                            MouseArea {
                                id: navArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.id === "player") { root.popupMode = "mini"; return }
                                    searchDebounce.stop()
                                    root.page = modelData.id
                                    if (modelData.id === "home" && root.homeCacheReady && root.quickPicks.length + root.homeMixes.length === 0) root.fetchHome(false)
                                    if (modelData.id === "library" && root.libraryCacheReady && root.libraryItems.length === 0) root.fetchLibrary(false)
                                    if (modelData.id === "search") Qt.callLater(function() { searchField.forceActiveFocus() })
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 8

                    Text { text: "ACCOUNT"; color: Colors.outline; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2 }

                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 8
                        color: Colors.surfaceContainer
                        border.color: sidebar.browserListOpen ? Colors.primary : Qt.alpha(Colors.outline, 0.4)
                        Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: root.browserLabel(root.selectedBrowser); color: Colors.fg; font.pixelSize: 11 }
                        Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: sidebar.browserListOpen ? "▴" : "▾"; color: Colors.outline; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sidebar.browserListOpen = !sidebar.browserListOpen }
                    }

                    Column {
                        width: parent.width
                        spacing: 2
                        visible: sidebar.browserListOpen
                        Repeater {
                            model: root.browserOptions
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selected: modelData.value === root.selectedBrowser
                                width: parent.width
                                height: 26
                                radius: 6
                                color: selected ? Qt.alpha(Colors.primary, 0.2) : optionArea.containsMouse ? Qt.alpha(Colors.outline, 0.2) : "transparent"
                                Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: selected ? Colors.primary : Colors.fg; font.pixelSize: 11 }
                                MouseArea {
                                    id: optionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedBrowser = modelData.value
                                        musicPreferences.browser = modelData.value
                                        sidebar.browserListOpen = false
                                    }
                                }
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 30
                            radius: 8
                            color: openSiteArea.containsMouse ? Qt.alpha(Colors.outline, 0.25) : Colors.surfaceContainer
                            Text { anchors.centerIn: parent; text: "Open site"; color: Colors.primary; font.pixelSize: 11 }
                            MouseArea { id: openSiteArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openMusicSite() }
                        }
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 30
                            radius: 8
                            color: connectArea.containsMouse ? Qt.alpha(Colors.secondary, 0.35) : Qt.alpha(Colors.secondary, 0.2)
                            Text { anchors.centerIn: parent; text: "Connect"; color: Colors.secondary; font.pixelSize: 11; font.bold: true }
                            MouseArea { id: connectArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.connectAccount() }
                        }
                    }
                }
            }

            // ---------- main area ----------
            Item {
                id: mainArea
                anchors.left: sidebar.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: nowPlaying.top
                anchors.leftMargin: 6
                anchors.rightMargin: 16
                anchors.topMargin: 14
                anchors.bottomMargin: 10

                Column {
                    id: headerColumn
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 10

                    Item {
                        id: pageHeader
                        width: parent.width
                        height: 52

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                visible: root.page === "collection"
                                width: 32
                                height: 32
                                radius: 16
                                anchors.verticalCenter: parent.verticalCenter
                                color: backArea.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                                Text { anchors.centerIn: parent; text: "‹"; color: Colors.primary; font.pixelSize: 20 }
                                MouseArea {
                                    id: backArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.page = root.collectionOrigin
                                }
                            }

                            Column {
                                spacing: 3
                                width: pageHeader.width - 260 - (root.page === "collection" ? 42 : 0)
                                Text {
                                    width: parent.width
                                    text: root.pageTitle()
                                    color: Colors.fg
                                    font.pixelSize: 24
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Row {
                                    spacing: 6
                                    width: parent.width
                                    LoadingSpinner {
                                        width: 12
                                        height: 12
                                        dotSize: 3
                                        visible: root.trackLoading || apiProcess.running
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        width: parent.width - ((root.trackLoading || apiProcess.running) ? 18 : 0)
                                        text: root.pageCount() + " items" + ((apiProcess.running || root.trackLoading || /fail|could not|error|expired|connect|not found/i.test(root.statusText)) ? "  ·  " + root.statusText : "")
                                        color: Colors.outline
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                visible: root.page === "home" || root.page === "library"
                                width: 92
                                height: 32
                                radius: 16
                                color: refreshArea.containsMouse ? Qt.alpha(Colors.secondary, 0.35) : Qt.alpha(Colors.secondary, 0.2)
                                Text { anchors.centerIn: parent; text: "↻  Refresh"; color: Colors.secondary; font.pixelSize: 11; font.bold: true }
                                MouseArea { id: refreshArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page === "home" ? root.fetchHome(true) : root.fetchLibrary(true) }
                            }
                            Rectangle {
                                visible: root.page === "collection"
                                width: 92
                                height: 32
                                radius: 16
                                color: playAllArea.containsMouse ? Qt.darker(Colors.primary, 1.15) : Colors.primary
                                Text { anchors.centerIn: parent; text: "▶  Play all"; color: Colors.fgPrimary; font.pixelSize: 11; font.bold: true }
                                MouseArea { id: playAllArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.playCollectionAt(0) }
                            }
                            Rectangle {
                                visible: root.page === "queue"
                                width: 80
                                height: 32
                                radius: 16
                                opacity: root.queue.length > 0 ? 1 : 0.45
                                color: clearQueueArea.containsMouse && root.queue.length > 0 ? Qt.alpha(Colors.error, 0.35) : Qt.alpha(Colors.error, 0.15)
                                Text { anchors.centerIn: parent; text: "Clear"; color: Colors.error; font.pixelSize: 11; font.bold: true }
                                MouseArea { id: clearQueueArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearQueue() }
                            }
                            Text {
                                text: "×"
                                color: Colors.fgDim
                                font.pixelSize: 24
                                width: 28
                                horizontalAlignment: Text.AlignHCenter
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closePopup() }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 38
                        spacing: 8
                        visible: root.page === "search"
                        TextField {
                            id: searchField
                            width: parent.width - 46
                            height: 38
                            leftPadding: 14
                            placeholderText: "Search songs, albums, playlists"
                            color: Colors.fg
                            placeholderTextColor: Colors.outline
                            selectionColor: Colors.primary
                            font.pixelSize: 13
                            background: Rectangle { radius: 19; color: Colors.surfaceContainerHigh; border.color: searchField.activeFocus ? Colors.primary : Qt.alpha(Colors.outline, 0.4) }
                            onTextChanged: { root.searchText = text; root.scheduleSearch() }
                            onAccepted: root.searchNow()
                        }
                        Rectangle {
                            width: 38
                            height: 38
                            radius: 19
                            color: searchArea.containsMouse ? Qt.darker(Colors.primary, 1.15) : Colors.primary
                            Text { anchors.centerIn: parent; text: "⌕"; color: Colors.fgPrimary; font.pixelSize: 18 }
                            MouseArea { id: searchArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.searchNow() }
                        }
                    }

                    Row {
                        spacing: 8
                        visible: root.page === "search"
                        Repeater {
                            model: [ { id: "songs", label: "Songs" }, { id: "albums", label: "Albums" }, { id: "playlists", label: "Playlists" } ]
                            delegate: Rectangle {
                                required property var modelData
                                width: 84
                                height: 26
                                radius: 13
                                color: root.searchType === modelData.id ? Qt.alpha(Colors.primary, 0.22) : Colors.surfaceContainerHigh
                                Text { anchors.centerIn: parent; text: modelData.label; color: root.searchType === modelData.id ? Colors.primary : Colors.fgDim; font.pixelSize: 11 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.searchType === modelData.id) return
                                        root.searchType = modelData.id
                                        if (root.searchText.trim().length > 0) root.searchNow()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.page === "queue" && root.queue.length > 0
                        text: "Drag the grip on the left of a row to reorder"
                        color: Colors.outline
                        font.pixelSize: 11
                    }
                }

                Item {
                    id: listArea
                    property int dragFrom: -1
                    property real dragY: 0
                    readonly property int rowStep: 56
                    readonly property int dragTarget: dragFrom < 0 ? -1
                        : Math.max(0, Math.min(root.queue.length - 1, Math.floor((dragY + searchList.contentY) / rowStep)))
                    anchors.top: headerColumn.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    ListView {
                                id: searchList
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: loadMore.visible ? loadMore.top : parent.bottom
                                anchors.bottomMargin: loadMore.visible ? 6 : 0
                                clip: true
                                cacheBuffer: root.page === "queue" ? 20000 : 320
                                model: root.listModel()
                                spacing: 2
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

                                delegate: Item {
                                    id: rowItem
                                    required property var modelData
                                    required property int index
                                    width: searchList.width - 2
                                    height: modelData.header ? 26 : 54
                                    opacity: root.page === "queue" && listArea.dragFrom === index ? 0.3 : 1

                                    Text {
                                        visible: !!modelData.header
                                        text: modelData.header || ""
                                        color: Colors.outline
                                        font.pixelSize: 9
                                        font.bold: true
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        visible: !modelData.header
                                        anchors.fill: parent
                                        radius: 8
                                        color: root.isCurrentTrack(modelData) ? Qt.alpha(Colors.primary, 0.25)
                                            : rowHover.hovered ? Colors.surfaceContainerHigh : "transparent"

                                        HoverHandler { id: rowHover }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.activatePanelItem(modelData, index)
                                        }

                                        Rectangle {
                                            visible: root.isCurrentTrack(modelData)
                                            width: 3
                                            height: 26
                                            radius: 1.5
                                            color: Colors.primary
                                            anchors.left: parent.left
                                            anchors.leftMargin: 2
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: root.page === "queue" ? 30 : 12
                                            anchors.rightMargin: 14
                                            spacing: 10

                                            Rectangle {
                                                width: 38
                                                height: 38
                                                radius: 6
                                                color: Colors.surfaceContainer
                                                clip: true
                                                anchors.verticalCenter: parent.verticalCenter
                                                Image {
                                                    id: rowThumbnail
                                                    anchors.fill: parent
                                                    source: modelData.thumbnail || ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    visible: status === Image.Ready
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "♫"
                                                    color: Colors.primary
                                                    font.pixelSize: 16
                                                    visible: rowThumbnail.status !== Image.Ready
                                                }
                                            }

                                            Column {
                                                width: parent.width - 38 - 10 - 74
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                Text {
                                                    width: parent.width
                                                    text: modelData.title || ""
                                                    color: root.isCurrentTrack(modelData) ? Colors.primary : Colors.fg
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    width: parent.width
                                                    text: [
                                                        modelData.kind && modelData.kind !== "song"
                                                            ? modelData.kind.charAt(0).toUpperCase() + modelData.kind.slice(1) : "",
                                                        modelData.artist || "",
                                                        modelData.album || "",
                                                        modelData.duration > 0 ? root.formatTime(modelData.duration) : ""
                                                    ].filter(function(value) { return value && value !== "0:00" }).join(" · ")
                                                    color: Colors.outline
                                                    font.pixelSize: 9
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Row {
                                                width: 74
                                                spacing: 6
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text {
                                                    visible: modelData.duration > 0
                                                    text: root.formatTime(modelData.duration)
                                                    color: Colors.outline
                                                    font.pixelSize: 9
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Rectangle {
                                                    width: 24
                                                    height: 24
                                                    radius: 6
                                                    color: actionHover.hovered ? Qt.alpha(Colors.outline, 0.4) : "transparent"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { anchors.centerIn: parent; text: root.actionGlyph(modelData); color: Colors.primary; font.pixelSize: 15 }
                                                    MouseArea {
                                                        id: actionHover
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (root.page === "queue") root.removeQueueItem(index)
                                                            else if (root.page === "library" || modelData.kind !== "song") root.openCollection(modelData)
                                                            else root.addTrackEnd(modelData)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: queueGrip
                                        visible: root.page === "queue" && !modelData.header
                                        width: 30
                                        height: parent.height
                                        anchors.left: parent.left
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        z: 20
                                        function updateDrag(mouse) {
                                            listArea.dragY = queueGrip.mapToItem(listArea, mouse.x, mouse.y).y
                                        }
                                        onPressed: function(mouse) {
                                            root.holdPopup = true
                                            popupCloseTimer.stop()
                                            listArea.dragFrom = index
                                            updateDrag(mouse)
                                        }
                                        onPositionChanged: function(mouse) { if (pressed) updateDrag(mouse) }
                                        onReleased: {
                                            const from = listArea.dragFrom
                                            const to = listArea.dragTarget
                                            const keepY = searchList.contentY
                                            listArea.dragFrom = -1
                                            root.holdPopup = false
                                            if (from >= 0 && to >= 0 && from !== to) {
                                                root.moveQueueItem(from, to)
                                                Qt.callLater(function() { searchList.contentY = keepY })
                                            }
                                        }
                                        onCanceled: {
                                            listArea.dragFrom = -1
                                            root.holdPopup = false
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "⠿"
                                            color: queueGrip.pressed || queueGrip.containsMouse ? Colors.primary : Colors.outline
                                            font.pixelSize: 15
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                visible: searchList.count === 0 && !root.listLoading

                                LoadingSpinner {
                                    width: 22
                                    height: 22
                                    dotSize: 6
                                    visible: apiProcess.running
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.emptyMessage()
                                    color: Colors.outline
                                    font.pixelSize: 11
                                }
                            }

                    Skeleton {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: searchList.count === 0 && root.listLoading
                    }

                    Rectangle {
                        id: dragGhost
                        readonly property var track: listArea.dragFrom >= 0 && listArea.dragFrom < root.queue.length ? root.queue[listArea.dragFrom] : null
                        visible: track !== null
                        z: 60
                        x: 0
                        width: listArea.width - 2
                        height: 54
                        y: Math.max(0, Math.min(listArea.height - height, listArea.dragY - height / 2))
                        radius: 8
                        color: Qt.alpha(Colors.surfaceContainerHigh, 0.97)
                        border.color: Colors.primary
                        border.width: 1
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 38
                            anchors.rightMargin: 12
                            spacing: 10
                            Image {
                                width: 40
                                height: 40
                                anchors.verticalCenter: parent.verticalCenter
                                source: dragGhost.track ? dragGhost.track.thumbnail : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 52
                                spacing: 2
                                Text { width: parent.width; text: dragGhost.track ? dragGhost.track.title : ""; color: Colors.fg; font.pixelSize: 11; elide: Text.ElideRight }
                                Text { width: parent.width; text: dragGhost.track ? dragGhost.track.artist : ""; color: Colors.outline; font.pixelSize: 9; elide: Text.ElideRight }
                            }
                        }
                    }

                    Rectangle {
                        visible: listArea.dragFrom >= 0 && listArea.dragTarget !== listArea.dragFrom
                        z: 55
                        height: 3
                        radius: 2
                        color: Colors.primary
                        width: listArea.width - 2
                        y: (listArea.dragTarget > listArea.dragFrom
                            ? listArea.dragTarget * listArea.rowStep + 55
                            : listArea.dragTarget * listArea.rowStep - 1) - searchList.contentY - 1
                    }

                    Timer {
                        interval: 16
                        repeat: true
                        running: listArea.dragFrom >= 0
                        onTriggered: {
                            const maxY = Math.max(0, searchList.contentHeight - searchList.height)
                            if (listArea.dragY < 40) searchList.contentY = Math.max(0, searchList.contentY - 8)
                            else if (listArea.dragY > listArea.height - 40) searchList.contentY = Math.min(maxY, searchList.contentY + 8)
                        }
                    }

                    Rectangle {
                        id: loadMore
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 32
                        radius: 16
                        visible: root.page === "collection" && root.nextPageToken !== ""
                        color: loadMoreArea.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                        Text { anchors.centerIn: parent; text: "Load more tracks"; color: Colors.primary; font.pixelSize: 11; font.bold: true }
                        MouseArea {
                            id: loadMoreArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.fetchMoreTracks()
                        }
                    }
                }
            }

            // ---------- now playing bar ----------
            Rectangle {
                id: nowPlaying
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                height: 92
                radius: 14
                color: Colors.surfaceContainerHigh

                Item {
                    id: npLeft
                    width: 300
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Rectangle {
                        id: npArt
                        width: 64
                        height: 64
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.surfaceContainer
                        clip: true
                        Image {
                            id: artworkImage
                            anchors.fill: parent
                            source: root.currentTrack ? root.currentTrack.thumbnail : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Text { anchors.centerIn: parent; text: "♫"; color: Colors.primary; font.pixelSize: 26; visible: !root.currentTrack || artworkImage.status !== Image.Ready }
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.alpha(Colors.surface, 0.8)
                            visible: root.trackLoading
                            LoadingSpinner { anchors.centerIn: parent; width: 22; height: 22; dotSize: 5 }
                        }
                    }

                    Column {
                        anchors.left: npArt.right
                        anchors.leftMargin: 12
                        anchors.right: npLike.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            width: parent.width
                            text: root.currentTrack ? root.currentTrack.title : "Nothing playing"
                            color: Colors.fg
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.currentTrack ? root.currentTrack.artist : "Pick something from the library"
                            color: Colors.fgDim
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        id: npLike
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        size: 20
                        glyph: root.currentTrack && root.likedIds[root.currentTrack.id] ? "♥" : "♡"
                        tint: root.currentTrack && root.likedIds[root.currentTrack.id] ? Colors.error : Colors.outline
                        onClicked: root.toggleLike()
                    }
                }

                Item {
                    id: npRight
                    width: 250
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        spacing: 8
                        Text {
                            text: root.muted ? "󰖁" : "󰕾"
                            color: Colors.primary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.sendMpv(["cycle", "mute"]) }
                        }
                        ThemedSlider {
                            width: 130
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 100
                            value: root.volumeLevel
                            onMoved: root.setPlayerVolume(value)
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "∞"
                            size: 17
                            tint: root.autoplay ? Colors.primary : Colors.outline
                            onClicked: root.autoplay = !root.autoplay
                        }
                    }
                }

                Item {
                    anchors.left: npLeft.right
                    anchors.right: npRight.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Column {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, 480)
                        spacing: 4

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 14
                            IconButton { anchors.verticalCenter: parent.verticalCenter; glyph: "⤨"; size: 16; tint: root.shuffleEnabled ? Colors.primary : Colors.outline; onClicked: root.toggleShuffle() }
                            IconButton { anchors.verticalCenter: parent.verticalCenter; glyph: "⏮"; size: 19; onClicked: root.previousTrack() }
                            Rectangle {
                                width: 38
                                height: 38
                                radius: 19
                                color: npPlayArea.pressed ? Qt.darker(Colors.primary, 1.2) : Colors.primary
                                Text { anchors.centerIn: parent; text: root.playing ? "⏸" : "▶"; color: Colors.fgPrimary; font.pixelSize: 17 }
                                MouseArea { id: npPlayArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlayback() }
                            }
                            IconButton { anchors.verticalCenter: parent.verticalCenter; glyph: "⏭"; size: 19; onClicked: root.nextTrack() }
                            IconButton { anchors.verticalCenter: parent.verticalCenter; glyph: root.repeatMode === 0 ? "↻" : root.repeatMode === 1 ? "↻¹" : "↻²"; size: 16; tint: root.repeatMode === 0 ? Colors.outline : Colors.primary; onClicked: root.cycleRepeat() }
                        }

                        Row {
                            width: parent.width
                            spacing: 8
                            Text { text: root.formatTime(root.position); color: Colors.fgDim; font.pixelSize: 10; width: 32; anchors.verticalCenter: parent.verticalCenter }
                            ThemedSlider {
                                id: playerSeek
                                width: parent.width - 80
                                anchors.verticalCenter: parent.verticalCenter
                                from: 0
                                to: Math.max(1, root.duration)
                                value: Math.min(root.position, to)
                                enabled: root.currentTrack !== null && root.duration > 0
                                onMoved: root.sendMpv(["set_property", "time-pos", value])
                            }
                            Text { text: root.formatTime(root.duration); color: Colors.fgDim; font.pixelSize: 10; width: 32; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }
    }

    MiniPlayer {
        player: root
    }
}
