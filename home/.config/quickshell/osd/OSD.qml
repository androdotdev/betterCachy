import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Scope {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  property bool showVolume: false
  property bool showBrightness: false
  property real volumeValue: 0
  property bool volumeMuted: false
  property real brightnessValue: 0
  property real maxBrightness: 1
  property bool _brightnessReady: false

  // PipeWire tracking
  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  Connections {
    target: Pipewire.defaultAudioSink?.audio ?? null

    function onVolumesChanged() {
      root.volumeValue = Pipewire.defaultAudioSink.audio.volume;
      root.showBrightness = false;
      brightnessHideTimer.stop();
      root.showVolume = true;
      volumeHideTimer.restart();
    }

    function onMutedChanged() {
      root.volumeMuted = Pipewire.defaultAudioSink.audio.muted;
      root.showBrightness = false;
      brightnessHideTimer.stop();
      root.showVolume = true;
      volumeHideTimer.restart();
    }
  }

  Timer {
    id: volumeHideTimer
    interval: 1800
    onTriggered: root.showVolume = false
  }

  // Brightness monitoring
  FileView {
    id: brightnessFile
    path: ""
    watchChanges: true
    onFileChanged: brightnessReadProc.running = true
  }

  Process {
    id: brightnessReadProc
    command: ["brightnessctl", "get"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const val = parseInt(text.trim());
        if (!isNaN(val) && root.maxBrightness > 0) {
          root.brightnessValue = val / root.maxBrightness;
          if (root._brightnessReady) {
            root.showVolume = false;
            volumeHideTimer.stop();
            root.showBrightness = true;
            brightnessHideTimer.restart();
          }
          root._brightnessReady = true;
        }
      }
    }
  }

  Process {
    id: backlightDiscovery
    command: ["sh", "-c", "p=$(ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -1); [ -n \"$p\" ] && echo \"$p\" && cat \"${p%brightness}max_brightness\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines.length >= 2) {
          const max = parseInt(lines[1]);
          if (!isNaN(max) && max > 0) root.maxBrightness = max;
          brightnessFile.path = lines[0];
          brightnessReadProc.running = true;
        }
      }
    }
  }

  Timer {
    id: brightnessHideTimer
    interval: 1800
    onTriggered: root.showBrightness = false
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      visible: root.showVolume || root.showBrightness
      focusable: false
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "quickshell-osd"

      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      anchors {
        right: true
        top: true
      }

      implicitWidth: 310
      implicitHeight: 166

      Column {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 14
        spacing: 8

        Rectangle {
          id: volumePill
          visible: root.showVolume
          width: 282
          height: 68
          radius: 16
          color: root.theme.bgBase
          border.color: root.theme.bgBorder
          border.width: 1

          Accessible.role: Accessible.ProgressBar
          Accessible.name: root.volumeMuted ? "Volume: muted" : "Volume: " + Math.round(root.volumeValue * 100) + "%"

          Column {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 9
            Row {
              width: parent.width
              Text { text: "VOLUME"; color: root.theme.textSecondary; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
              Item { width: parent.width - 100; height: 1 }
              Text { text: root.volumeMuted ? "Muted" : Math.round(root.volumeValue * 100) + "%"; color: root.theme.textPrimary; font.pixelSize: 12; font.bold: true }
            }
            Rectangle {
              id: volumeTrack
              width: parent.width
              height: 8
              radius: 4
              color: root.theme.bgSurface
              clip: true
              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.volumeMuted ? 0 : root.volumeValue))
                height: parent.height
                radius: parent.radius
                color: root.volumeMuted ? root.theme.textMuted : root.theme.accentPrimary
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              }
            }
          }
        }

        Rectangle {
          id: brightnessPill
          visible: root.showBrightness
          width: 282
          height: 68
          radius: 16
          color: root.theme.bgBase
          border.color: root.theme.bgBorder
          border.width: 1

          Accessible.role: Accessible.ProgressBar
          Accessible.name: "Brightness: " + Math.round(root.brightnessValue * 100) + "%"

          Column {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 9
            Row {
              width: parent.width
              Text { text: "BRIGHTNESS"; color: root.theme.textSecondary; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
              Item { width: parent.width - 112; height: 1 }
              Text { text: Math.round(root.brightnessValue * 100) + "%"; color: root.theme.textPrimary; font.pixelSize: 12; font.bold: true }
            }
            Rectangle {
              id: brightnessTrack
              width: parent.width
              height: 8
              radius: 4
              color: root.theme.bgSurface
              clip: true
              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.brightnessValue))
                height: parent.height
                radius: parent.radius
                color: root.theme.accentOrange
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              }
            }
          }
        }
      }
    }
  }
}
