import AppKit
import Foundation
import ServiceManagement
import SwiftUI

public enum CodexMonitorBootstrap {
    @MainActor
    public static func makeAppDelegate() -> NSObject & NSApplicationDelegate {
        AppDelegate()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, @unchecked Sendable {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let mcpSnapshotStore = MCPSnapshotStore()
    private let store = CodexMonitorStore()

    private let menu = NSMenu()
    private let summaryView = StatusSummaryView(
        frame: NSRect(x: 0, y: 0, width: StatusSummaryView.preferredWidth, height: 246)
    )

    private var mainWindow: NSWindow?
    private var timer: Timer?
    private lazy var mcpServer = MCPHTTPServer(port: AppMeta.defaultMCPPort) { [weak self] in
        guard let self else { return Data("{}".utf8) }
        return self.mcpSnapshotStore.get()
    }
    private let toolbarIdentifier = NSToolbar.Identifier("com.yls.codex-monitor.window-toolbar")

    private var supportsLaunchAtLogin: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        bindStore()
        store.loadConfiguration()
        syncLaunchAtLoginOnStartup()
        setupSummaryView()
        setupMenu()
        setupStatusButton()
        startPolling()
        startMCPIfNeeded()
        mcpSnapshotStore.set(makeMCPSnapshotData())
        showMainWindow()
        store.refreshNow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        mcpServer.stop()
    }

    private func bindStore() {
        store.onStateChange = { [weak self] in
            guard let self else { return }
            self.renderSummaryView()
            self.renderStatusBar()
            self.rebuildStatusMenu()
        }
    }

    private func setupStatusButton() {
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemMouseUp(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        store.initializeStatusFallback()
        renderSummaryView()
        renderStatusBar()
    }

    private func setupSummaryView() {
        summaryView.onTogglePanelMode = { [weak self] in
            self?.store.togglePanelMode()
        }
        summaryView.onToggleEmail = { [weak self] in
            self?.store.toggleEmailVisibility()
        }
        summaryView.onRefresh = { [weak self] in
            self?.performMenuAction {
                self?.store.refreshNow()
            }
        }
        summaryView.onSelectStatisticsMode = { [weak self] in
            self?.performMenuAction {
                self?.handleSelectStatisticsMode()
            }
        }
        summaryView.onSelectSource = { [weak self] in
            self?.performMenuAction {
                self?.handleSelectSource()
            }
        }
        summaryView.onSetAPIKey = { [weak self] in
            self?.performMenuAction {
                self?.handleSetAPIKey()
            }
        }
        summaryView.onSetAGIKey = { [weak self] in
            self?.performMenuAction {
                self?.handleSetAGIKey()
            }
        }
        summaryView.onSetInterval = { [weak self] in
            self?.performMenuAction {
                self?.handleSetInterval()
            }
        }
        summaryView.onOpenDashboard = { [weak self] in
            self?.performMenuAction {
                self?.handleOpenDashboard()
            }
        }
        summaryView.onOpenPricing = { [weak self] in
            self?.performMenuAction {
                self?.handleOpenPricing()
            }
        }
        summaryView.onSelectUsageLogsPage = { [weak self] page in
            self?.performMenuAction {
                self?.store.selectUsageLogsPage(page)
            }
        }
        summaryView.onOpenUsageLogDetail = { [weak self] rawURL in
            self?.performMenuAction {
                self?.handleOpenUsageLogDetail(rawURL)
            }
        }
        summaryView.onSelectDisplayStyle = { [weak self] style in
            self?.store.selectDisplayStyle(style)
        }
        summaryView.onToggleSourceGroup = { [weak self] source in
            self?.store.toggleSourceGroup(source)
        }
        summaryView.onToggleLaunchAtLogin = { [weak self] enabled in
            self?.setLaunchAtLogin(enabled)
        }
        summaryView.onConfigureMCP = { [weak self] in
            self?.performMenuAction {
                self?.handleConfigureMCP()
            }
        }
        summaryView.onConfigureStatusColor = { [weak self] in
            self?.performMenuAction {
                self?.handleConfigureStatusColor()
            }
        }
        summaryView.onQuit = { [weak self] in
            self?.performMenuAction {
                self?.handleQuit()
            }
        }
        renderSummaryView()
    }

    private func setupMenu() {
        menu.delegate = self
        rebuildStatusMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        store.hideEmail()
        rebuildStatusMenu()
    }

    @objc private func handleStatusItemMouseUp(_ sender: NSStatusBarButton) {
        popUpStatusMenu(menu)
    }

    private func rebuildStatusMenu() {
        menu.removeAllItems()

        let dailyRemainingText = store.apiKey.isEmpty ? "未配置Key" : store.latestDailyRemaining
        let dailyItem = NSMenuItem(title: "每日剩余额度：\(dailyRemainingText)", action: nil, keyEquivalent: "")
        dailyItem.isEnabled = false
        menu.addItem(dailyItem)

        let weeklyRemainingText = store.apiKey.isEmpty ? "未配置Key" : store.latestWeeklyRemaining
        let weeklyItem = NSMenuItem(title: "每周剩余额度：\(weeklyRemainingText)", action: nil, keyEquivalent: "")
        weeklyItem.isEnabled = false
        menu.addItem(weeklyItem)

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "打开主窗口", action: #selector(handleOpenMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(handleRefreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func handleRefreshNow() {
        store.refreshNow()
    }

    @objc private func handleOpenMainWindow() {
        showMainWindow()
    }

    private func handleSelectStatisticsMode() {
        let alert = NSAlert()
        alert.messageText = "选择统计模式"
        alert.informativeText = "单显显示当前套餐源；双显会同时显示 Codex 和 AGI 两组统计，状态栏默认优先显示 Codex。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let selector = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 28), pullsDown: false)
        StatisticsDisplayMode.allCases.forEach { mode in
            selector.addItem(withTitle: mode.fullTitle)
        }
        selector.selectItem(at: StatisticsDisplayMode.allCases.firstIndex(of: store.statisticsDisplayMode) ?? 0)
        alert.accessoryView = selector

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        store.selectStatisticsDisplayMode(StatisticsDisplayMode.allCases[selector.indexOfSelectedItem])
    }

    private func handleSelectSource() {
        let alert = NSAlert()
        alert.messageText = "选择单显套餐源"
        alert.informativeText = "单显模式下的统计面板会跟随当前选择的数据源；双显模式下仍会同时展示 Codex 和 AGI。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let selector = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 28), pullsDown: false)
        PackageSource.allCases.forEach { source in
            selector.addItem(withTitle: source.title)
        }
        selector.selectItem(at: PackageSource.allCases.firstIndex(of: store.currentSource) ?? 0)
        alert.accessoryView = selector

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        store.selectSource(PackageSource.allCases[selector.indexOfSelectedItem])
    }

    private func popUpStatusMenu(_ menu: NSMenu) {
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
    }

    private func showMainWindow() {
        let window = mainWindow ?? makeMainWindow()
        mainWindow = window
        renderSummaryView()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeMainWindow() -> NSWindow {
        summaryView.translatesAutoresizingMaskIntoConstraints = true
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: summaryView.intrinsicContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = AppMeta.displayName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        configureWindowToolbar(for: window)
        window.contentView = summaryView
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: StatusSummaryView.preferredWidth, height: 420)
        window.center()
        return window
    }

    private func configureWindowToolbar(for window: NSWindow) {
        let toolbar = NSToolbar(identifier: toolbarIdentifier)
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .default
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        if #available(macOS 11.0, *) {
            toolbar.showsBaselineSeparator = false
            window.toolbarStyle = .unifiedCompact
            window.titlebarSeparatorStyle = .none
        }
        window.toolbar = toolbar
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: store.pollInterval,
            target: self,
            selector: #selector(handleTimerTick),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func handleTimerTick() {
        store.refreshNow()
    }

    @objc private func handleSetAPIKey() {
        let alert = NSAlert()
        alert.messageText = PackageSource.codex.apiKeyDialogTitle
        alert.informativeText = PackageSource.codex.apiKeyDialogHint
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.stringValue = store.apiKey
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        store.setAPIKey(input.stringValue)
    }

    @objc private func handleSetAGIKey() {
        let alert = NSAlert()
        alert.messageText = PackageSource.agi.apiKeyDialogTitle
        alert.informativeText = PackageSource.agi.apiKeyDialogHint
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.stringValue = store.agiAPIKey
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        store.setAGIKey(input.stringValue)
    }

    @objc private func handleSetInterval() {
        let alert = NSAlert()
        alert.messageText = "设置轮询间隔（秒）"
        alert.informativeText = "建议 >= 3 秒"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        input.placeholderString = "例如 5"
        input.stringValue = String(Int(store.pollInterval))
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let value = Double(input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard store.setPollInterval(value) else {
            showError("轮询间隔必须 >= 1 秒")
            return
        }
        startPolling()
    }

    @objc private func handleOpenDashboard() {
        guard let rawURL = store.currentSource.dashboardURL,
              let url = URL(string: rawURL) else {
            showError("控制台链接无效")
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func handleConfigureMCP() {
        let alert = NSAlert()
        alert.messageText = "MCP 服务设置"
        alert.informativeText = "启动应用时自动在本机启动一个 HTTP MCP 快照服务，供 AI 连接读取最新数据。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 82))

        let checkbox = NSButton(checkboxWithTitle: "启用 MCP 本地服务", target: nil, action: nil)
        checkbox.frame = NSRect(x: 0, y: 56, width: 220, height: 20)
        checkbox.state = store.mcpEnabled ? .on : .off
        container.addSubview(checkbox)

        let label = NSTextField(labelWithString: "端口")
        label.frame = NSRect(x: 0, y: 28, width: 40, height: 22)
        container.addSubview(label)

        let input = NSTextField(frame: NSRect(x: 44, y: 24, width: 120, height: 24))
        input.stringValue = String(store.mcpPort)
        container.addSubview(input)

        let hint = NSTextField(labelWithString: "示例地址: http://\(AppMeta.mcpHost):\(store.mcpPort)/mcp/snapshot")
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 0, y: 0, width: 340, height: 22)
        container.addSubview(hint)

        alert.accessoryView = container

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let enabled = checkbox.state == .on
        let parsedPort = UInt16(input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard parsedPort > 0 else {
            showError("MCP 端口必须是 1-65535 之间的数字")
            return
        }

        store.setMCPConfiguration(enabled: enabled, port: parsedPort)
        restartMCPIfNeeded()
        renderSummaryView()
    }

    @objc private func handleConfigureStatusColor() {
        let alert = NSAlert()
        alert.messageText = "状态栏文本颜色"
        alert.informativeText = "可自动适配状态栏背景，也可手动设置文本/圆环颜色。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 104))

        let autoAdaptCheckbox = NSButton(checkboxWithTitle: "根据状态栏背景自动适配", target: nil, action: nil)
        autoAdaptCheckbox.frame = NSRect(x: 0, y: 80, width: 280, height: 20)
        autoAdaptCheckbox.state = store.statusBarForegroundMode == .autoAdapt ? .on : .off
        container.addSubview(autoAdaptCheckbox)

        let colorLabel = NSTextField(labelWithString: "手动颜色")
        colorLabel.frame = NSRect(x: 0, y: 50, width: 68, height: 22)
        container.addSubview(colorLabel)

        let colorWell = NSColorWell(frame: NSRect(x: 72, y: 46, width: 44, height: 28))
        colorWell.color = store.statusBarManualColor
        container.addSubview(colorWell)

        let colorHexLabel = NSTextField(labelWithString: store.statusBarManualColorHex)
        colorHexLabel.textColor = .secondaryLabelColor
        colorHexLabel.frame = NSRect(x: 124, y: 50, width: 90, height: 22)
        container.addSubview(colorHexLabel)

        let hint = NSTextField(
            labelWithString: "自动模式：深色背景用白色，浅色背景用黑色；无法判断时默认白色。"
        )
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 0, y: 4, width: 340, height: 38)
        hint.maximumNumberOfLines = 2
        hint.lineBreakMode = .byWordWrapping
        container.addSubview(hint)

        alert.accessoryView = container
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let mode: StatusBarForegroundMode = autoAdaptCheckbox.state == .on ? .autoAdapt : .manual
        store.setStatusBarColor(mode: mode, color: colorWell.color)
    }

    @objc private func handleOpenPricing() {
        guard let rawURL = store.currentSource.pricingURL,
              let url = URL(string: rawURL) else {
            showError("续费链接无效")
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func handleOpenUsageLogDetail(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            handleOpenDashboard()
            return
        }

        if let direct = URL(string: trimmed), direct.scheme != nil {
            NSWorkspace.shared.open(direct)
            return
        }

        if trimmed.hasPrefix("/"), let composed = URL(string: "https://code.ylsagi.com\(trimmed)") {
            NSWorkspace.shared.open(composed)
            return
        }

        handleOpenDashboard()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let previous = store.launchAtLoginEnabled
        do {
            try syncLaunchAtLoginWithSystem(enabled: enabled)
            store.setLaunchAtLoginEnabled(enabled)
        } catch {
            store.setLaunchAtLoginEnabled(previous)
            showError("开机自启设置失败：\(error.localizedDescription)")
        }
    }

    private func syncLaunchAtLoginOnStartup() {
        do {
            try syncLaunchAtLoginWithSystem(enabled: store.launchAtLoginEnabled)
        } catch {
        }
    }

    private func syncLaunchAtLoginWithSystem(enabled: Bool) throws {
        guard supportsLaunchAtLogin else { return }
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                switch service.status {
                case .enabled:
                    break
                default:
                    try service.register()
                }
            } else {
                switch service.status {
                case .enabled, .requiresApproval:
                    try service.unregister()
                default:
                    break
                }
            }
        }
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }

    private func startMCPIfNeeded() {
        guard store.mcpEnabled else {
            mcpServer.stop()
            return
        }
        do {
            try mcpServer.updatePort(store.mcpPort)
        } catch {
            mcpServer.stop()
            mcpServer.lastError = error.localizedDescription
        }
    }

    private func restartMCPIfNeeded() {
        mcpServer.stop()
        startMCPIfNeeded()
    }

    private func currentMCPStatusText() -> String {
        if !store.mcpEnabled {
            return "已关闭"
        }
        if mcpServer.isRunning {
            return "http://\(AppMeta.mcpHost):\(store.mcpPort)/mcp/snapshot"
        }
        if let error = mcpServer.lastError, !error.isEmpty {
            return "启动失败: \(error)"
        }
        return "启动中..."
    }

    private func makeMCPSnapshotData() -> Data {
        store.makeMCPSnapshotData(mcpStatusText: currentMCPStatusText())
    }

    private func renderSummaryView() {
        summaryView.apply(
            store.makeSummaryModel(
                supportsLaunchAtLogin: supportsLaunchAtLogin,
                mcpStatusText: currentMCPStatusText()
            )
        )
        mcpSnapshotStore.set(makeMCPSnapshotData())
    }

    private func performMenuAction(_ action: @escaping () -> Void) {
        menu.cancelTracking()
        DispatchQueue.main.async {
            action()
        }
    }

    private func renderStatusBar() {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .noImage
        let primaryColor = resolvedStatusBarForegroundColor(for: button)
        let secondaryColor = primaryColor.withAlphaComponent(0.68)
        let snapshot = store.statusBarSnapshot()

        guard snapshot.remaining != "--" else {
            applySingleLineTitle(snapshot.fallbackText, color: primaryColor)
            return
        }

        let clampedUsed = snapshot.usedPercent.map { max(0, min(100, $0)) }
        let remainingPercent = clampedUsed.map { max(0, 100 - $0) }

        switch store.displayStyle {
        case .remaining:
            applySingleLineTitle("余: \(snapshot.remaining)", color: primaryColor)
        case .usedPercent:
            if let clampedUsed {
                applySingleLineTitle(String(format: "用: %.2f%%", clampedUsed), color: primaryColor)
            } else {
                applySingleLineTitle("用: \(snapshot.usage)", color: primaryColor)
            }
        case .remainingPercent:
            if let remainingPercent {
                applySingleLineTitle(String(format: "剩: %.2f%%", remainingPercent), color: primaryColor)
            } else {
                applySingleLineTitle("剩: --", color: primaryColor)
            }
        case .stackedUsedPercent:
            let top = clampedUsed.map { String(format: "%.2f%%", $0) } ?? "--"
            applyTwoLineImage(top: top, bottom: "已使用", primaryColor: primaryColor, secondaryColor: secondaryColor)
        case .stackedRemainingPercent:
            let top = remainingPercent.map { String(format: "%.2f%%", $0) } ?? "--"
            applyTwoLineImage(top: top, bottom: "剩余", primaryColor: primaryColor, secondaryColor: secondaryColor)
        case .circleProgress:
            applyCircleProgressWithRemaining(
                progress: clampedUsed.map { $0 / 100 },
                remainingText: "余: \(snapshot.remaining)",
                primaryColor: primaryColor,
                secondaryColor: secondaryColor
            )
        }
    }

    private func resolvedStatusBarForegroundColor(for button: NSStatusBarButton?) -> NSColor {
        switch store.statusBarForegroundMode {
        case .manual:
            return store.statusBarManualColor
        case .autoAdapt:
            guard let button else { return .white }
            let matched = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            if matched == .aqua {
                return .black
            }
            return .white
        }
    }

    private func applySingleLineTitle(_ text: String, size: CGFloat = 12, color: NSColor) {
        guard let button = statusItem.button else { return }
        statusItem.length = NSStatusItem.variableLength
        button.alignment = .center
        button.cell?.wraps = false
        button.cell?.lineBreakMode = .byClipping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: color
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
    }

    private func applyTwoLineImage(top: String, bottom: String, primaryColor: NSColor, secondaryColor: NSColor) {
        guard let button = statusItem.button else { return }
        let targetWidth = makeStackedTargetWidth(top: top, bottom: bottom)
        statusItem.length = targetWidth
        button.attributedTitle = NSAttributedString(string: "")
        let targetHeight = max(AppMeta.stackedStatusHeight, floor(button.bounds.height))
        button.image = makeStackedTextImage(
            top: top,
            bottom: bottom,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            topColor: primaryColor,
            bottomColor: secondaryColor
        )
        button.imagePosition = .imageOnly
    }

    private func makeStackedTargetWidth(top: String, bottom: String) -> CGFloat {
        let topFont = NSFont.systemFont(ofSize: AppMeta.stackedTopFontSize, weight: .semibold)
        let bottomFont = NSFont.systemFont(ofSize: AppMeta.stackedBottomFontSize, weight: .medium)
        let topWidth = ceil((top as NSString).size(withAttributes: [.font: topFont]).width)
        let bottomWidth = ceil((bottom as NSString).size(withAttributes: [.font: bottomFont]).width)
        let contentWidth = max(topWidth, bottomWidth)
        let target = contentWidth + AppMeta.stackedHorizontalPadding * 2
        return max(AppMeta.stackedStatusMinWidth, min(AppMeta.stackedStatusMaxWidth, target))
    }

    private func makeStackedTextImage(
        top: String,
        bottom: String,
        targetWidth: CGFloat,
        targetHeight: CGFloat,
        topColor: NSColor,
        bottomColor: NSColor
    ) -> NSImage {
        let size = NSSize(width: targetWidth, height: targetHeight)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping

        let topFont = NSFont.systemFont(ofSize: AppMeta.stackedTopFontSize, weight: .semibold)
        let bottomFont = NSFont.systemFont(ofSize: AppMeta.stackedBottomFontSize, weight: .medium)

        let topAttrs: [NSAttributedString.Key: Any] = [
            .font: topFont,
            .foregroundColor: topColor,
            .paragraphStyle: paragraph
        ]
        let bottomAttrs: [NSAttributedString.Key: Any] = [
            .font: bottomFont,
            .foregroundColor: bottomColor,
            .paragraphStyle: paragraph
        ]

        let topText = NSAttributedString(string: top, attributes: topAttrs)
        let bottomText = NSAttributedString(string: bottom, attributes: bottomAttrs)
        let topHeight = ceil(topFont.ascender - topFont.descender)
        let bottomHeight = ceil(bottomFont.ascender - bottomFont.descender)
        let contentHeight = topHeight + AppMeta.stackedLineGap + bottomHeight
        let baseY = floor((size.height - contentHeight) / 2 + AppMeta.stackedVerticalNudge)

        let bottomY = baseY
        let topY = bottomY + bottomHeight + AppMeta.stackedLineGap

        topText.draw(in: NSRect(x: 0, y: topY, width: size.width, height: topHeight))
        bottomText.draw(in: NSRect(x: 0, y: bottomY, width: size.width, height: bottomHeight))

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func applyCircleProgressWithRemaining(
        progress: Double?,
        remainingText: String,
        primaryColor: NSColor,
        secondaryColor: NSColor
    ) {
        guard let button = statusItem.button else { return }
        let targetWidth = makeCircleTargetWidth(bottomText: remainingText)
        statusItem.length = targetWidth
        button.attributedTitle = NSAttributedString(string: "")
        let targetHeight = max(AppMeta.stackedStatusHeight, floor(button.bounds.height))
        button.image = makeCircleWithBottomTextImage(
            progress: progress ?? 0,
            bottomText: remainingText,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor
        )
        button.imagePosition = .imageOnly
    }

    private func makeCircleTargetWidth(bottomText: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: AppMeta.circleBottomFontSize, weight: .medium)
        let textWidth = ceil((bottomText as NSString).size(withAttributes: [.font: font]).width)
        let contentWidth = max(AppMeta.circleDiameter, textWidth)
        let target = contentWidth + AppMeta.circleHorizontalPadding * 2
        return max(AppMeta.circleMinWidth, min(AppMeta.circleMaxWidth, target))
    }

    private func makeCircleWithBottomTextImage(
        progress: Double,
        bottomText: String,
        targetWidth: CGFloat,
        targetHeight: CGFloat,
        primaryColor: NSColor,
        secondaryColor: NSColor
    ) -> NSImage {
        let size = NSSize(width: targetWidth, height: targetHeight)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true

        let clamped = max(0, min(1, progress))
        let bottomFont = NSFont.systemFont(ofSize: AppMeta.circleBottomFontSize, weight: .medium)
        let textHeight = ceil(bottomFont.ascender - bottomFont.descender)
        let circleSize = AppMeta.circleDiameter
        let contentHeight = circleSize + AppMeta.circleLineGap + textHeight
        let baseY = floor((size.height - contentHeight) / 2 + AppMeta.stackedVerticalNudge)
        let textY = baseY
        let circleY = textY + textHeight + AppMeta.circleLineGap
        let center = NSPoint(x: floor(size.width / 2), y: circleY + circleSize / 2)
        let radius = AppMeta.circleDiameter / 2
        let startAngle: CGFloat = 90
        let endAngle = startAngle - CGFloat(clamped * 360)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping
        NSAttributedString(
            string: bottomText,
            attributes: [
                .font: bottomFont,
                .foregroundColor: secondaryColor,
                .paragraphStyle: paragraph
            ]
        ).draw(in: NSRect(x: 0, y: textY, width: size.width, height: textHeight))

        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        bgPath.lineWidth = AppMeta.circleLineWidth
        primaryColor.withAlphaComponent(0.26).setStroke()
        bgPath.stroke()

        let fgPath = NSBezierPath()
        fgPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        fgPath.lineWidth = AppMeta.circleLineWidth
        primaryColor.setStroke()
        fgPath.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "配置错误"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}
