import QtQuick

Item {
    id: root
    required property var service
    required property int workspaceId
    property bool miniature: false
    readonly property var windows: service.windowsFor(workspaceId)
    readonly property real factor: Math.min(width / service.monitorWidth, height / service.monitorHeight)
    Item {
        width: root.service.monitorWidth * root.factor
        height: root.service.monitorHeight * root.factor
        anchors.centerIn: parent
        Repeater {
            model: root.windows
            WindowPreview {
                required property var modelData
                required property int index
                property var geometry: modelData.lastIpcObject
                service: root.service; windowHandle: modelData; miniature: root.miniature
                x: Math.max(0, ((geometry.at ? geometry.at[0] : 0) - (service.monitorData.x || 0)) * root.factor)
                y: Math.max(0, ((geometry.at ? geometry.at[1] : 0) - (service.monitorData.y || 0)) * root.factor)
                width: Math.max(8, (geometry.size ? geometry.size[0] : 400) * root.factor)
                height: Math.max(8, (geometry.size ? geometry.size[1] : 300) * root.factor)
                selected: !miniature && index === service.selectedWindow
                z: selected ? 1000 : index
                onActivated: { if (miniature) service.selectWorkspace(root.workspaceId); else service.focusWindow(modelData) }
            }
        }
        Text { anchors.centerIn: parent; visible: root.windows.length === 0; text: root.service.searchText.trim() ? (root.miniature ? "" : "No matching windows") : root.miniature ? "+" : "Empty workspace · Enter to switch"; color: ThemeTokens.secondary; font.pixelSize: root.miniature ? 24 : 18 }
    }
}
