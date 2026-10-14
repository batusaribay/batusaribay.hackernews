import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "batusaribay.hackernews"
  ipcTarget: "batusaribay.hackernews"
  manageIpc: false

  property var items: []
  property bool loading: false
  property bool savedChecked: false

  property int cursorIndex: 0
  property bool cursorActive: false

  property double lastFetchMs: 0
  property double nowMs: Date.now()

  readonly property int maxItems: {
    var n = Number(setting("maxItems", 7))
    return Math.max(3, Math.min(30, isFinite(n) ? Math.round(n) : 7))
  }

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string scriptPath: {
    var u = Qt.resolvedUrl("thn-fetch.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  readonly property string fetchedLabel: {
    if (loading)
      return "Fetching latest headlines…"
    if (lastFetchMs <= 0)
      return ""
    var s = Math.max(0, Math.floor((nowMs - lastFetchMs) / 1000))
    var rel
    if (s < 60)
      rel = "just now"
    else if (s < 3600)
      rel = Math.floor(s / 60) + "m ago"
    else if (s < 86400)
      rel = Math.floor(s / 3600) + "h ago"
    else
      rel = Math.floor(s / 86400) + "d ago"
    return "Fetched " + rel
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (fetchProcess.running)
      return
    loading = true
    fetchProcess.running = true
  }

  function applyPayload(raw) {
    var parsed = Model.parsePayload(raw)
    if (parsed.items.length > 0 || parsed.ok) {
      items = parsed.items
      if (cursorIndex >= items.length)
        cursorIndex = Math.max(0, items.length - 1)
    }
    var fetchedAt = Date.parse(parsed.updated || "")
    if (isFinite(fetchedAt) && fetchedAt > 0)
      lastFetchMs = fetchedAt
  }

  function loadSavedPayload(raw) {
    if (fetchProcess.running)
      return
    applyPayload(raw)
  }

  function moveCursor(dy) {
    if (items.length === 0)
      return
    cursorIndex = Math.max(0, Math.min(items.length - 1, cursorIndex + dy))
    ensureCursorVisible()
  }

  function ensureCursorVisible() {
    if (!flick || !listColumn)
      return
    var kids = listColumn.children
    for (var i = 0; i < kids.length; i++) {
      var k = kids[i]
      if (!k || k.rowIndex !== cursorIndex)
        continue
      var p = k.mapToItem(flick.contentItem, 0, 0)
      var top = p.y
      var bottom = top + k.height
      if (top < flick.contentY)
        flick.contentY = top
      else if (bottom > flick.contentY + flick.height)
        flick.contentY = Math.max(0, bottom - flick.height)
      return
    }
  }

  function selectedItem() {
    return items.length > 0 ? items[Math.max(0, Math.min(cursorIndex, items.length - 1))] : null
  }

  function openItem(item) {
    if (!item || !item.url)
      return
    Util.execArgv(["xdg-open", item.url])
    root.close()
  }

  function askItem(item) {
    if (!item)
      return
    Util.execArgv(["omarchy", "agent", "prompt", Model.buildPrompt(item)])
    root.close()
  }

  function copyItem(item) {
    if (!item || !item.url)
      return
    Util.execArgv(["wl-copy", item.url])
  }

  function activateCursor() {
    var item = selectedItem()
    if (item)
      openItem(item)
  }

  onOpenedChanged: {
    if (!opened)
      return
    nowMs = Date.now()
    if (items.length === 0 && !savedChecked && !fetchProcess.running && !cacheProcess.running)
      cacheProcess.running = true
  }

  onCursorIndexChanged: ensureCursorVisible()

  Process {
    id: fetchProcess
    command: ["bash", root.scriptPath, String(root.maxItems)]
    stdout: StdioCollector {
      id: fetchOut
      waitForEnd: true
      onStreamFinished: root.applyPayload(fetchOut.text)
    }
    stderr: StdioCollector {
      id: fetchErr
      waitForEnd: true
    }
    onExited: root.loading = false
  }

  Process {
    id: cacheProcess
    command: ["bash", root.scriptPath, "--cached"]
    stdout: StdioCollector {
      id: cacheOut
      waitForEnd: true
      onStreamFinished: root.loadSavedPayload(cacheOut.text)
    }
    onExited: root.savedChecked = true
  }

  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    foreground: root.foreground
    useActiveColor: false
    text: Model.MARK
    tooltipText: ""
    onPressed: function (b) {
      root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) {
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        if (dy !== 0)
          root.moveCursor(dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTextKey: function (t) {
        var k = String(t).toLowerCase()
        if (k === "r")
          root.refresh()
        else if (k === "j")
          root.moveCursor(1)
        else if (k === "k")
          root.moveCursor(-1)
        else if (k === "o")
          root.activateCursor()
        else if (k === "a")
          root.askItem(root.selectedItem())
        else if (k === "c")
          root.copyItem(root.selectedItem())
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: flick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Hacker News"
            meta: root.fetchedLabel
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: Model.MARK
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Column {
            id: listColumn
            visible: root.items.length > 0
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.items
              delegate: NewsRow {
                width: listColumn.width
                item: modelData
                rowIndex: index
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.items.length === 0
            width: parent.width
            topPadding: Style.space(6)
            bottomPadding: Style.space(6)
            text: root.loading
              ? "Fetching the latest headlines…"
              : "No headlines yet. Press r to refresh."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "j / k  move      Enter / o  open      a  ask agent      c  copy link      r  refresh      Esc  close"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  component NewsRow: CursorSurface {
    id: row
    property var item: null
    property int rowIndex: 0

    readonly property bool selected: root.cursorActive && row.rowIndex === root.cursorIndex

    hasCursor: selected
    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.space(12)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorIndex = row.rowIndex
        root.cursorActive = true
      }
      onClicked: root.openItem(row.item)
    }

    RowLayout {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: row.item ? row.item.title : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: row.item ? Model.metaLine(row.item) : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }
    }
  }
}
