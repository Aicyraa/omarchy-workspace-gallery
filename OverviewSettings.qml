import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    required property var service
    signal dismissed()
    function focusFirst() { sizeSlider.forceActiveFocus() }
    function toggleMotion() { service.reducedMotion = !service.reducedMotion; service.saveSettings({reducedMotion: service.reducedMotion}) }
    Keys.onEscapePressed: root.dismissed()
    Timer { id: sizeSave; interval: 180; onTriggered: root.service.saveSettings({previewScale: root.service.previewScale}) }
    Timer { id: durationSave; interval: 180; onTriggered: root.service.saveSettings({animationDuration: root.service.animationDuration}) }
    implicitWidth: 284; implicitHeight: 232
    radius: 15; color: ThemeTokens.panel; border.width: 1; border.color: ThemeTokens.border
    MouseArea { anchors.fill: parent }
    Text { x: 18; y: 16; text: "Overview preferences"; font.pixelSize: 14; font.weight: Font.Medium; color: ThemeTokens.text }
    Text { x: 18; y: 51; text: "Preview size"; font.pixelSize: 11; color: ThemeTokens.secondary }
    Text { anchors { top: parent.top; right: parent.right; margins: 18; topMargin: 51 } text: Math.round(root.service.previewScale * 100) + "%"; font.pixelSize: 11; color: ThemeTokens.text }
    Slider {
        id: sizeSlider; x: 16; y: 70; width: parent.width - 32; height: 24
        from: 0.65; to: 1; stepSize: 0.01; value: root.service.previewScale
        onMoved: { root.service.previewScale = value; sizeSave.restart() }
        onPressedChanged: if (!pressed) sizeSave.restart()
        Accessible.name: "Workspace preview size"
        background: Rectangle { x: sizeSlider.leftPadding; y: sizeSlider.height / 2 - 2; width: sizeSlider.availableWidth; height: 4; radius: 2; color: ThemeTokens.track; Rectangle { width: parent.width * sizeSlider.visualPosition; height: 4; radius: 2; color: ThemeTokens.accent } }
        handle: Rectangle { x: sizeSlider.leftPadding + sizeSlider.visualPosition * (sizeSlider.availableWidth - width); y: sizeSlider.height / 2 - 5; width: 10; height: 10; radius: 5; color: ThemeTokens.accent }
    }
    Text { x: 18; y: 107; text: "Transition duration"; font.pixelSize: 11; color: ThemeTokens.secondary }
    Text { anchors { top: parent.top; right: parent.right; margins: 18; topMargin: 107 } text: root.service.reducedMotion ? "Off" : root.service.animationDuration + " ms"; font.pixelSize: 11; color: ThemeTokens.text }
    Slider {
        id: speedSlider; x: 16; y: 126; width: parent.width - 32; height: 24
        from: 120; to: 500; stepSize: 10; value: root.service.animationDuration
        enabled: !root.service.reducedMotion; opacity: enabled ? 1 : 0.4
        onMoved: { root.service.animationDuration = Math.round(value); durationSave.restart() }
        onPressedChanged: if (!pressed) durationSave.restart()
        Accessible.name: "Transition duration"
        background: Rectangle { x: speedSlider.leftPadding; y: speedSlider.height / 2 - 2; width: speedSlider.availableWidth; height: 4; radius: 2; color: ThemeTokens.track; Rectangle { width: parent.width * speedSlider.visualPosition; height: 4; radius: 2; color: ThemeTokens.accent } }
        handle: Rectangle { x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width); y: speedSlider.height / 2 - 5; width: 10; height: 10; radius: 5; color: ThemeTokens.accent }
    }
    Text { x: 18; y: 173; text: "Reduced motion"; font.pixelSize: 12; color: ThemeTokens.text }
    Text { x: 18; y: 194; text: "Instant switching, without tilt or fades"; font.pixelSize: 10; color: ThemeTokens.secondary }
    Rectangle {
        anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 174 }
        activeFocusOnTab: true
        Keys.onReturnPressed: root.toggleMotion()
        Keys.onSpacePressed: root.toggleMotion()
        border.width: activeFocus ? 1 : 0; border.color: ThemeTokens.accent
        width: 32; height: 18; radius: 9; color: root.service.reducedMotion ? ThemeTokens.accent : ThemeTokens.track
        Rectangle { x: root.service.reducedMotion ? 17 : 3; y: 3; width: 12; height: 12; radius: 6; color: root.service.reducedMotion ? ThemeTokens.onAccent : ThemeTokens.secondary }
        MouseArea {
            anchors.fill: parent
            onClicked: { parent.forceActiveFocus(); root.toggleMotion() }
            Accessible.role: Accessible.CheckBox; Accessible.name: "Reduced motion"; Accessible.checked: root.service.reducedMotion
        }
    }
}
