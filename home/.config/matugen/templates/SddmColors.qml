import QtQuick 2.15

QtObject {
    readonly property color primary: "{{colors.primary.default.hex}}"
    readonly property color fgPrimary: "{{colors.on_primary.default.hex}}"
    readonly property color surface: "{{colors.surface.default.hex}}"
    readonly property color surfaceContainer: "{{colors.surface_container.default.hex}}"
    readonly property color surfaceContainerHigh: "{{colors.surface_container_high.default.hex}}"
    readonly property color fg: "{{colors.on_surface.default.hex}}"
    readonly property color fgDim: "{{colors.on_surface_variant.default.hex}}"
    readonly property color outline: "{{colors.outline.default.hex}}"
    readonly property color error: "{{colors.error.default.hex}}"
}
