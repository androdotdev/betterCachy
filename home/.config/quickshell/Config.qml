pragma Singleton

import Quickshell
import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
//  betterCachy shell settings
//
//  This is the one file to edit when you want to change how the desktop looks
//  or which parts of the bar are enabled. Values are read when Quickshell
//  starts, so apply a change with:
//
//      systemctl --user restart quickshell.service
//
//  Runtime toggles that are saved from the bar (auto-hide, reserve space,
//  do-not-disturb, dock pins) live in database.json and are not duplicated
//  here. Everything below is design/config, not personal state.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    // ── Bar and notch geometry ───────────────────────────────────────────────
    // panelHeight is the clickable/reserved strip at the top of the screen.
    property int panelHeight: 36
    // The visible capsule. Keep it smaller than panelHeight so it floats.
    property int notchHeight: 32
    property int notchRadius: 16
    // Vertical gap between the screen edge and the capsule.
    property int notchTop: 2
    // Width when the notch only shows the clock / indicators.
    property int collapsedWidth: 340
    // Maximum width when expanded. The real width is the smaller of this and
    // (screen width - screenEdgeMargin), so it always fits on narrow screens.
    property int expandedMaxWidth: 1180
    property int screenEdgeMargin: 60
    // How far the capsule slides off-screen when auto-hide hides it.
    property int hiddenOffset: 44
    // Height of the strip that reveals a hidden notch when hovered. It is
    // centered above where the capsule will appear, not across the whole bar.
    property int hiddenHoverHeight: 6

    // ── Animation timings (milliseconds) ─────────────────────────────────────
    property int hoverExpandDelay: 45
    property int hoverCollapseDelay: 150
    property int notchHideDelay: 260
    property int popupCloseDelay: 220
    // Keep the notch expanded for a moment after a popup closes. Without this
    // the bar collapses and expands again when you click a button to close it.
    property int popupCloseGrace: 400
    property int widthDuration: 260
    property int revealDuration: 240
    property int contentFadeDuration: 140

    // ── Feature toggles ──────────────────────────────────────────────────────
    // Expand the notch when the pointer is over the capsule. Set to false for
    // a permanently compact bar (also turn off auto-hide in Quick Settings).
    property bool hoverExpand: true
    // The ♫ capsule and the full YouTube Music / mini player.
    property bool musicButton: true
    // cava bars inside the music capsule and in the compact notch.
    property bool musicVisualizer: true
    // Bell, notification history and toast popups.
    property bool notifications: true
    // Battery percentage for laptops.
    property bool battery: true
    // Workspace number capsules on the left side of the expanded notch.
    property bool workspaces: true
    // System tray icons.
    property bool systemTray: true
    // Now-playing capsule in the middle of the expanded notch (MPRIS).
    property bool mediaWidget: true
    // Floating application dock at the bottom of the screen.
    property bool dock: true
}
