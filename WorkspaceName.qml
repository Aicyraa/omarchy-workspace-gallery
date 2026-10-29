import QtQuick

Item {
    id: root
    required property var service
    property bool editing: false
    property int editingId: 0
    signal finished()
    implicitWidth: Math.min(440, Math.max(180, nameLabel.implicitWidth + 52))
    implicitHeight: 36
    function beginEdit() {
        editingId = service.selectedWorkspace
        editor.text = service.workspaceName(editingId)
        editing = true
        Qt.callLater(function() { editor.forceActiveFocus(); editor.selectAll() })
    }
    function cancel() { editing = false; finished() }
    function commit() {
        if (!editing) return
        if (service.renameWorkspace(editingId, editor.text)) { editing = false; finished() }
    }
    Connections { target: root.service; function onSelectedWorkspaceChanged() { if (root.editing) root.cancel() } }
    Rectangle {
        anchors.fill: parent; radius: 10
        color: root.editing ? ThemeTokens.surface : nameMouse.containsMouse ? ThemeTokens.selected : "transparent"
        border.width: root.editing ? 1 : 0; border.color: ThemeTokens.border
    }
    Text {
        id: nameLabel; visible: !root.editing
        anchors.centerIn: parent
        text: root.service.workspaceName(root.service.selectedWorkspace)
        textFormat: Text.PlainText
        width: Math.min(implicitWidth, root.width - 48); elide: Text.ElideRight
        font.pixelSize: 14; font.weight: Font.Medium; color: ThemeTokens.text
    }
    Text { visible: !root.editing; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "✎"; color: ThemeTokens.secondary; font.pixelSize: 14 }
    MouseArea {
        id: nameMouse; anchors.fill: parent; enabled: !root.editing; hoverEnabled: true
        onClicked: root.beginEdit()
        Accessible.role: Accessible.Button
        Accessible.name: "Rename " + root.service.workspaceName(root.service.selectedWorkspace)
    }
    TextInput {
        id: editor; visible: root.editing
        anchors { left: parent.left; right: saveButton.left; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 8 }
        color: ThemeTokens.text; selectionColor: ThemeTokens.selectedHover
        selectedTextColor: ThemeTokens.text; font.pixelSize: 14
        maximumLength: 48; clip: true; selectByMouse: true
        Accessible.name: "Workspace name"
        Keys.onEscapePressed: event => { root.cancel(); event.accepted = true }
        onAccepted: root.commit()
    }
    Rectangle {
        id: saveButton; visible: root.editing
        anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
        width: 28; height: 26; radius: 7; color: ThemeTokens.selected
        Text { anchors.centerIn: parent; text: "✓"; color: ThemeTokens.accent }
        MouseArea { anchors.fill: parent; onClicked: root.commit(); Accessible.name: "Save workspace name"; Accessible.role: Accessible.Button }
    }
}
