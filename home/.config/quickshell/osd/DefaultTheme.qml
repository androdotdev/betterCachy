import QtQuick
import qs

QtObject {
  readonly property color bgBase: Colors.surface
  readonly property color bgSurface: Colors.surfaceContainer
  readonly property color bgOverlay: Qt.alpha(Colors.surface, 0.53)
  readonly property color bgHover: Colors.surfaceContainerHigh
  readonly property color bgSelected: Qt.alpha(Colors.primary, 0.25)
  readonly property color bgBorder: Qt.alpha(Colors.outline, 0.4)

  readonly property color textPrimary: Colors.fg
  readonly property color textSecondary: Colors.fgDim
  readonly property color textMuted: Colors.outline

  readonly property color accentPrimary: Colors.primary
  readonly property color accentCyan: Colors.primary
  readonly property color accentGreen: Colors.secondary
  readonly property color accentOrange: Colors.tertiary
  readonly property color accentRed: Colors.error

  readonly property color urgencyLow: textMuted
  readonly property color urgencyNormal: accentPrimary
  readonly property color urgencyCritical: accentRed
}
