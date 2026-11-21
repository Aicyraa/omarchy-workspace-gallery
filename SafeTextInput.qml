import QtQuick

// Plain-text single-line input implemented without native Qt text-edit types so
// Wayland clipboard offers never trigger automatic synchronous reads.
FocusScope {
    id: root

    property string text: ""
    property int maximumLength: 256
    property color color: ThemeTokens.text
    property color selectionColor: ThemeTokens.selectedHover
    property color selectedTextColor: ThemeTokens.text
    property font font
    property int cursorPosition: 0
    property int selectionStart: 0
    property int selectionEnd: 0
    property bool blinkCursor: true
    property real scrollX: 0
    property bool cursorShown: true

    readonly property bool hasSelection: selectionStart !== selectionEnd
    readonly property int selMin: Math.min(selectionStart, selectionEnd)
    readonly property int selMax: Math.max(selectionStart, selectionEnd)
    readonly property real caretX: metrics.advanceWidth(text.slice(0, cursorPosition))
    readonly property real selLeft: metrics.advanceWidth(text.slice(0, selMin))
    readonly property real selRight: metrics.advanceWidth(text.slice(0, selMax))

    signal accepted()
    signal textEdited(string text)

    clip: true
    activeFocusOnTab: true
    implicitWidth: Math.max(60, Math.ceil(displayText.implicitWidth) + 4)
    implicitHeight: Math.max(20, Math.ceil(displayText.implicitHeight))
    Accessible.role: Accessible.EditableText

    function clampPos(pos) {
        return Math.max(0, Math.min(text.length, pos))
    }

    function resetBlink() {
        cursorShown = true
        if (activeFocus && blinkCursor) blinkTimer.restart()
        else blinkTimer.stop()
    }

    function ensureCursorVisible() {
        if (width <= 0) {
            scrollX = 0
            return
        }
        var next = scrollX
        var margin = 2
        if (caretX - next > width - margin) next = caretX - (width - margin)
        else if (caretX - next < 0) next = caretX
        var maxScroll = Math.max(0, metrics.advanceWidth(text) + margin - width)
        scrollX = Math.max(0, Math.min(maxScroll, next))
    }

    function selectAll() {
        selectionStart = 0
        selectionEnd = text.length
        cursorPosition = text.length
        ensureCursorVisible()
        resetBlink()
    }

    function deselect() {
        selectionStart = cursorPosition
        selectionEnd = cursorPosition
    }

    function moveToEnd() {
        cursorPosition = text.length
        deselect()
        ensureCursorVisible()
        resetBlink()
    }

    function positionAt(px) {
        var target = px + scrollX
        if (target <= 0 || text.length === 0) return 0
        var lo = 0
        var hi = text.length
        while (lo < hi) {
            var mid = Math.floor((lo + hi) / 2)
            if (metrics.advanceWidth(text.slice(0, mid)) < target) lo = mid + 1
            else hi = mid
        }
        if (lo > 0) {
            var prevW = metrics.advanceWidth(text.slice(0, lo - 1))
            var currW = metrics.advanceWidth(text.slice(0, lo))
            if (Math.abs(target - prevW) < Math.abs(currW - target)) return lo - 1
        }
        return lo
    }

    function prevWordPos(pos) {
        var i = clampPos(pos)
        while (i > 0 && /\s/.test(text.charAt(i - 1))) i--
        while (i > 0 && !/\s/.test(text.charAt(i - 1))) i--
        return i
    }

    function nextWordPos(pos) {
        var i = clampPos(pos)
        while (i < text.length && /\s/.test(text.charAt(i))) i++
        while (i < text.length && !/\s/.test(text.charAt(i))) i++
        return i
    }

    function moveCursor(newPos, keepSelection) {
        cursorPosition = clampPos(newPos)
        if (!keepSelection) deselect()
        else selectionEnd = cursorPosition
        ensureCursorVisible()
        resetBlink()
    }

    function applyEdit(from, to, inserted) {
        var start = clampPos(Math.min(from, to))
        var end = clampPos(Math.max(from, to))
        var removed = end - start
        var available = Math.max(0, maximumLength - (text.length - removed))
        var chunk = inserted ? inserted.slice(0, available) : ""
        if (removed === 0 && chunk.length === 0) return false
        var next = text.slice(0, start) + chunk + text.slice(end)
        text = next
        cursorPosition = start + chunk.length
        deselect()
        ensureCursorVisible()
        resetBlink()
        textEdited(next)
        return true
    }

    onTextChanged: {
        cursorPosition = clampPos(cursorPosition)
        selectionStart = clampPos(selectionStart)
        selectionEnd = clampPos(selectionEnd)
        ensureCursorVisible()
    }

    onCursorPositionChanged: ensureCursorVisible()
    onWidthChanged: ensureCursorVisible()
    onActiveFocusChanged: {
        if (activeFocus) resetBlink()
        else {
            blinkTimer.stop()
            cursorShown = false
        }
    }
    onBlinkCursorChanged: resetBlink()

    FontMetrics {
        id: metrics
        font: root.font
    }

    Timer {
        id: blinkTimer
        interval: 530
        repeat: true
        running: root.activeFocus && root.blinkCursor
        onTriggered: root.cursorShown = !root.cursorShown
    }

    Rectangle {
        visible: root.hasSelection && root.selRight > root.selLeft
        x: root.selLeft - root.scrollX
        y: displayText.y
        width: Math.max(0, root.selRight - root.selLeft)
        height: displayText.height
        color: root.selectionColor
    }

    Text {
        id: displayText
        x: -root.scrollX
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        textFormat: Text.PlainText
        color: root.color
        font: root.font
    }

    Rectangle {
        x: root.caretX - root.scrollX
        y: displayText.y + 1
        width: 1.5
        height: Math.max(12, displayText.height - 2)
        color: root.color
        visible: root.activeFocus && (!root.blinkCursor || root.cursorShown)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.IBeamCursor
        onPressed: mouse => {
            root.forceActiveFocus()
            var pos = root.positionAt(mouse.x)
            if (mouse.modifiers & Qt.ShiftModifier) {
                root.cursorPosition = pos
                root.selectionEnd = pos
            } else {
                root.cursorPosition = pos
                root.selectionStart = pos
                root.selectionEnd = pos
            }
            root.ensureCursorVisible()
            root.resetBlink()
        }
        onPositionChanged: mouse => {
            if (!(mouse.buttons & Qt.LeftButton)) return
            var pos = root.positionAt(mouse.x)
            root.cursorPosition = pos
            root.selectionEnd = pos
            root.ensureCursorVisible()
            root.resetBlink()
        }
        onDoubleClicked: root.selectAll()
    }

    Item {
        id: inputArea
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
            var shift = (event.modifiers & Qt.ShiftModifier) !== 0
            var alt = (event.modifiers & Qt.AltModifier) !== 0
            var meta = (event.modifiers & Qt.MetaModifier) !== 0

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.accepted()
                event.accepted = true
                return
            }

            // Explicit navigation and parent-owned shortcuts bubble up untouched.
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab
                    || event.key === Qt.Key_Up || event.key === Qt.Key_Down
                    || event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown
                    || (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35)) {
                event.accepted = false
                return
            }

            // Explicitly ignore clipboard shortcuts so no clipboard read occurs.
            if ((ctrl && (event.key === Qt.Key_V || event.key === Qt.Key_C || event.key === Qt.Key_X))
                    || (shift && event.key === Qt.Key_Insert)
                    || event.key === Qt.Key_Paste || event.key === Qt.Key_Copy || event.key === Qt.Key_Cut) {
                event.accepted = true
                return
            }

            if (ctrl && !alt && !meta && event.key === Qt.Key_A) {
                root.selectAll()
                event.accepted = true
                return
            }

            if (ctrl && !alt && !meta && event.key === Qt.Key_U) {
                if (root.text.length > 0) root.applyEdit(0, root.text.length, "")
                event.accepted = true
                return
            }

            if (ctrl && !alt && !meta && (event.key === Qt.Key_W || event.key === Qt.Key_Backspace)) {
                if (root.hasSelection) root.applyEdit(root.selMin, root.selMax, "")
                else if (root.cursorPosition > 0) root.applyEdit(root.prevWordPos(root.cursorPosition), root.cursorPosition, "")
                event.accepted = true
                return
            }

            if (ctrl && !alt && !meta && event.key === Qt.Key_Delete) {
                if (root.hasSelection) root.applyEdit(root.selMin, root.selMax, "")
                else if (root.cursorPosition < root.text.length) root.applyEdit(root.cursorPosition, root.nextWordPos(root.cursorPosition), "")
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Backspace) {
                if (root.hasSelection) {
                    root.applyEdit(root.selMin, root.selMax, "")
                } else if (root.cursorPosition > 0) {
                    var delStart = root.cursorPosition - 1
                    if (delStart > 0) {
                        var trail = root.text.charCodeAt(delStart)
                        var lead = root.text.charCodeAt(delStart - 1)
                        if (trail >= 0xDC00 && trail <= 0xDFFF && lead >= 0xD800 && lead <= 0xDBFF) delStart--
                    }
                    root.applyEdit(delStart, root.cursorPosition, "")
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Delete) {
                if (root.hasSelection) {
                    root.applyEdit(root.selMin, root.selMax, "")
                } else if (root.cursorPosition < root.text.length) {
                    var delEnd = root.cursorPosition + 1
                    if (delEnd < root.text.length) {
                        var leadDel = root.text.charCodeAt(root.cursorPosition)
                        var trailDel = root.text.charCodeAt(delEnd)
                        if (leadDel >= 0xD800 && leadDel <= 0xDBFF && trailDel >= 0xDC00 && trailDel <= 0xDFFF) delEnd++
                    }
                    root.applyEdit(root.cursorPosition, delEnd, "")
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Left) {
                if (!shift && root.hasSelection) root.moveCursor(root.selMin, false)
                else root.moveCursor(ctrl ? root.prevWordPos(root.cursorPosition) : root.cursorPosition - 1, shift)
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Right) {
                if (!shift && root.hasSelection) root.moveCursor(root.selMax, false)
                else root.moveCursor(ctrl ? root.nextWordPos(root.cursorPosition) : root.cursorPosition + 1, shift)
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Home) {
                root.moveCursor(0, shift)
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_End) {
                root.moveCursor(root.text.length, shift)
                event.accepted = true
                return
            }

            if (!ctrl && !alt && !meta && event.text) {
                var clean = event.text.replace(/[\x00-\x1f\x7f]/g, "")
                if (clean.length > 0) {
                    if (root.hasSelection) root.applyEdit(root.selMin, root.selMax, clean)
                    else root.applyEdit(root.cursorPosition, root.cursorPosition, clean)
                    event.accepted = true
                    return
                }
            }

            event.accepted = false
        }
    }
}
