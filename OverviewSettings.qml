import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    required property var service
    signal dismissed()
    function focusFirst() { sizeSlider.forceActiveFocus() }
    component ToggleSwitch: Rectangle {
        id: toggle
        property bool checked: false
        property string label: ""
        signal toggled()
        activeFocusOnTab: true
        Keys.onReturnPressed: toggled()
        Keys.onSpacePressed: toggled()
        border.width: activeFocus ? 1 : 0; border.color: ThemeTokens.accent
        width: 32; height: 18; radius: 9; color: checked ? ThemeTokens.accent : ThemeTokens.track
        Rectangle { x: toggle.checked ? 17 : 3; y: 3; width: 12; height: 12; radius: 6; color: toggle.checked ? ThemeTokens.onAccent : ThemeTokens.secondary }
        MouseArea {
            anchors.fill: parent
            onClicked: { toggle.forceActiveFocus(); toggle.toggled() }
            Accessible.role: Accessible.CheckBox; Accessible.name: toggle.label; Accessible.checked: toggle.checked
        }
    }
    function toggleMotion() { service.reducedMotion = !service.reducedMotion; service.saveSettings({reducedMotion: service.reducedMotion}) }
    Keys.onEscapePressed: root.dismissed()
    Timer { id: sizeSave; interval: 180; onTriggered: root.service.saveSettings({previewScale: root.service.previewScale}) }
    Timer { id: durationSave; interval: 180; onTriggered: root.service.saveSettings({animationDuration: root.service.animationDuration}) }
    implicitWidth: 284; implicitHeight: 430
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
    Text { x: 18; y: 229; text: "Key guide"; font.pixelSize: 12; color: ThemeTokens.text }
    Text { x: 18; y: 250; text: "Show the shortcut legend (F1 toggles it)"; font.pixelSize: 10; color: ThemeTokens.secondary }
    ToggleSwitch {
        anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 230 }
        label: "Key guide"; checked: root.service.showKeyGuide
        onToggled: root.service.setPreference("showKeyGuide", !root.service.showKeyGuide)
    }
    Text { x: 18; y: 281; text: "Open in ring view"; font.pixelSize: 12; color: ThemeTokens.text }
    Text { x: 18; y: 302; text: "Start in the 3D ring instead of the flat view"; font.pixelSize: 10; color: ThemeTokens.secondary }
    ToggleSwitch {
        anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 282 }
        label: "Open in ring view"; checked: root.service.defaultView === "orbit"
        onToggled: root.service.setPreference("defaultView", root.service.defaultView === "orbit" ? "classic" : "orbit")
    }
    Text { x: 18; y: 333; text: "Live other workspaces"; font.pixelSize: 12; color: ThemeTokens.text }
    Text { x: 18; y: 354; text: "Keep video and animations moving. Uses more GPU"; font.pixelSize: 10; color: ThemeTokens.secondary }
    ToggleSwitch {
        anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 334 }
        label: "Live other workspaces"; checked: root.service.liveOtherWorkspaces
        onToggled: root.service.setPreference("liveOtherWorkspaces", !root.service.liveOtherWorkspaces)
    }
    Text { x: 18; y: 385; text: "High-quality previews"; font.pixelSize: 12; color: ThemeTokens.text }
    Text { x: 18; y: 406; text: "Smoother, less shimmery text. Uses more memory"; font.pixelSize: 10; color: ThemeTokens.secondary }
    ToggleSwitch {
        anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 386 }
        label: "High-quality previews"; checked: root.service.highQuality
        onToggled: root.service.setPreference("previewQuality", root.service.highQuality ? "standard" : "high")
    }
}
