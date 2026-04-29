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

    private var launchAtLoginUnsupportedReason: String? {
        guard #available(macOS 13.0, *) else {
            return "仅支持 macOS 13 或更高版本。"
        }
        let bundlePath = Bundle.main.bundleURL.path
        guard bundlePath.hasSuffix(".app") else {
            return "当前运行环境不是 .app 包，无法启用开机自启。"
        }
        if bundlePath.contains("/.build/") || bundlePath.contains("/DerivedData/") {
            return "调试构建不支持开机自启，请使用导出的 .app 再开启。"
        }
        return nil
    }

    private var supportsLaunchAtLogin: Bool {
        launchAtLoginUnsupportedReason == nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        setupMainMenu()
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

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于 \(AppMeta.displayName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 \(AppMeta.displayName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            .keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 \(AppMeta.displayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        mcpServer.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
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
        summaryView.onSelectStatisticsMode = { [weak self] mode in
            self?.performMenuAction {
                self?.store.selectStatisticsDisplayMode(mode)
            }
        }
        summaryView.onSelectSource = { [weak self] source in
            self?.performMenuAction {
                self?.store.selectSource(source)
            }
        }
        summaryView.onSetAPIKey = { [weak self] source, token in
            self?.performMenuAction {
                self?.store.setAPIKey(token, for: source)
            }
        }
        summaryView.onSetInterval = { [weak self] seconds in
            self?.performMenuAction {
                guard let self else { return }
                guard self.store.setPollInterval(seconds) else {
                    self.showError("轮询间隔必须 >= 1 秒")
                    return
                }
                self.startPolling()
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
            self?.performMenuAction {
                self?.setLaunchAtLogin(enabled)
            }
        }
        summaryView.onConfigureMCP = { [weak self] enabled, port in
            self?.performMenuAction {
                guard let self else { return }
                self.store.setMCPConfiguration(enabled: enabled, port: port)
                self.restartMCPIfNeeded()
                self.renderSummaryView()
            }
        }
        summaryView.onSetStatusBarColor = { [weak self] mode, manualColorHex in
            self?.performMenuAction {
                guard let self else { return }
                let color = Self.colorFromHexString(manualColorHex) ?? self.store.statusBarManualColor
                self.store.setStatusBarColor(mode: mode, color: color)
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

    private func popUpStatusMenu(_ menu: NSMenu) {
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
    }

    private func showMainWindow() {
        let window = mainWindow ?? makeMainWindow()
        mainWindow = window
        renderSummaryView()
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
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

    @objc private func handleOpenDashboard() {
        guard let rawURL = store.currentSource.dashboardURL,
              let url = URL(string: rawURL) else {
            showError("控制台链接无效")
            return
        }
        NSWorkspace.shared.open(url)
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
        if let reason = launchAtLoginUnsupportedReason {
            store.setLaunchAtLoginEnabled(false)
            showError("开机自启设置失败：\(reason)")
            return
        }
        do {
            try syncLaunchAtLoginWithSystem(enabled: enabled)
            store.setLaunchAtLoginEnabled(enabled)
        } catch {
            store.setLaunchAtLoginEnabled(previous)
            showError("开机自启设置失败：\(readableLaunchAtLoginError(error))")
        }
    }

    private func syncLaunchAtLoginOnStartup() {
        guard supportsLaunchAtLogin else {
            store.setLaunchAtLoginEnabled(false)
            return
        }
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
                case .enabled:
                    try service.unregister()
                default:
                    break
                }
            }
        }
    }

    private func readableLaunchAtLoginError(_ error: Error) -> String {
        if let reason = launchAtLoginUnsupportedReason {
            return reason
        }
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("Invalid argument") {
            return "系统拒绝了该请求。请将应用以 .app 形式运行后重试。"
        }
        return text
    }

    private static func colorFromHexString(_ rawValue: String) -> NSColor? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let hex = UInt32(value, radix: 16) else {
            return nil
        }
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
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
                launchAtLoginUnavailableReason: launchAtLoginUnsupportedReason,
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

        let hasDisplayData = snapshot.dailyUsedAmount != "--"
            || snapshot.dailyRemainingAmount != "--"
            || snapshot.weeklyUsedAmount != "--"
            || snapshot.weeklyRemainingAmount != "--"
            || snapshot.dailyUsedPercent != nil
            || snapshot.weeklyUsedPercent != nil

        guard hasDisplayData else {
            applySingleLineTitle(snapshot.fallbackText, color: primaryColor)
            return
        }

        let dailyUsedPercent = snapshot.dailyUsedPercent.map { max(0, min(100, $0)) }
        let dailyRemainingPercent = dailyUsedPercent.map { max(0, 100 - $0) }
        let weeklyUsedPercent = snapshot.weeklyUsedPercent.map { max(0, min(100, $0)) }
        let weeklyRemainingPercent = weeklyUsedPercent.map { max(0, 100 - $0) }

        switch store.displayStyle {
        case .dailyUsedAmount:
            applySingleLineTitle("日用：\(snapshot.dailyUsedAmount)", color: primaryColor)
        case .dailyRemainingAmount:
            applySingleLineTitle("日余：\(snapshot.dailyRemainingAmount)", color: primaryColor)
        case .dailyUsedCircle:
            applyCircleProgressWithRemaining(
                progress: dailyUsedPercent.map { $0 / 100 },
                remainingText: "日用：\(snapshot.dailyUsedAmount)",
                primaryColor: primaryColor,
                secondaryColor: secondaryColor
            )
        case .dailyRemainingCircle:
            applyCircleProgressWithRemaining(
                progress: dailyRemainingPercent.map { $0 / 100 },
                remainingText: "日余：\(snapshot.dailyRemainingAmount)",
                primaryColor: primaryColor,
                secondaryColor: secondaryColor
            )
        case .dailyUsedPercent:
            if let dailyUsedPercent {
                applySingleLineTitle(String(format: "日用：%.2f%%", dailyUsedPercent), color: primaryColor)
            } else {
                applySingleLineTitle("日用：--", color: primaryColor)
            }
        case .dailyRemainingPercent:
            if let dailyRemainingPercent {
                applySingleLineTitle(String(format: "日余：%.2f%%", dailyRemainingPercent), color: primaryColor)
            } else {
                applySingleLineTitle("日余：--", color: primaryColor)
            }
        case .weeklyUsedAmount:
            applySingleLineTitle("周用：\(snapshot.weeklyUsedAmount)", color: primaryColor)
        case .weeklyRemainingAmount:
            applySingleLineTitle("周余：\(snapshot.weeklyRemainingAmount)", color: primaryColor)
        case .weeklyUsedCircle:
            applyCircleProgressWithRemaining(
                progress: weeklyUsedPercent.map { $0 / 100 },
                remainingText: "周用：\(snapshot.weeklyUsedAmount)",
                primaryColor: primaryColor,
                secondaryColor: secondaryColor
            )
        case .weeklyRemainingCircle:
            applyCircleProgressWithRemaining(
                progress: weeklyRemainingPercent.map { $0 / 100 },
                remainingText: "周余：\(snapshot.weeklyRemainingAmount)",
                primaryColor: primaryColor,
                secondaryColor: secondaryColor
            )
        case .weeklyUsedPercent:
            if let weeklyUsedPercent {
                applySingleLineTitle(String(format: "周用：%.2f%%", weeklyUsedPercent), color: primaryColor)
            } else {
                applySingleLineTitle("周用：--", color: primaryColor)
            }
        case .weeklyRemainingPercent:
            if let weeklyRemainingPercent {
                applySingleLineTitle(String(format: "周余：%.2f%%", weeklyRemainingPercent), color: primaryColor)
            } else {
                applySingleLineTitle("周余：--", color: primaryColor)
            }
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
