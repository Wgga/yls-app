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
    private var scheduledTaskTimer: Timer?
    private var lastPresentedScheduledTaskOccurrence: String?
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
        observeScheduledTaskReminderRequests()
        startPolling()
        startScheduledTaskReminderTimer()
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
        scheduledTaskTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
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

    private func startScheduledTaskReminderTimer() {
        scheduledTaskTimer?.invalidate()
        scheduledTaskTimer = Timer.scheduledTimer(
            timeInterval: 15,
            target: self,
            selector: #selector(handleScheduledTaskTimerTick),
            userInfo: nil,
            repeats: true
        )
        presentScheduledTaskReminderIfDue()
    }

    @objc private func handleTimerTick() {
        store.refreshNow()
    }

    @objc private func handleScheduledTaskTimerTick() {
        presentScheduledTaskReminderIfDue()
    }

    private func observeScheduledTaskReminderRequests() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScheduledTaskReminderRequested(_:)),
            name: .scheduledTaskReminderRequested,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScheduledTaskReminderConfigurationChanged),
            name: .scheduledTaskReminderConfigurationChanged,
            object: nil
        )
    }

    @objc private func handleScheduledTaskReminderRequested(_ notification: Notification) {
        let reminders = ScheduledTaskReminder.fromDefaults(requireEnabled: false)
        let reminder: ScheduledTaskReminder?
        if let id = notification.object as? String {
            reminder = reminders.first { $0.id == id }
        } else {
            reminder = reminders.first
        }

        guard let reminder else { return }
        showScheduledTaskReminder(reminder)
    }

    @objc private func handleScheduledTaskReminderConfigurationChanged() {
        lastPresentedScheduledTaskOccurrence = nil
        presentScheduledTaskReminderIfDue()
    }

    private func presentScheduledTaskReminderIfDue(at date: Date = Date()) {
        let calendar = Calendar.current
        for reminder in ScheduledTaskReminder.fromDefaults(requireEnabled: true) {
            guard reminder.isDue(at: date, calendar: calendar) else { continue }

            let occurrenceID = reminder.occurrenceID(at: date, calendar: calendar)
            guard occurrenceID != lastPresentedScheduledTaskOccurrence else { continue }

            lastPresentedScheduledTaskOccurrence = occurrenceID
            showScheduledTaskReminder(reminder)
            return
        }
    }

    private func showScheduledTaskReminder(_ reminder: ScheduledTaskReminder) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = ScheduledTaskReminderPanel(reminder: reminder) { [weak self] in
            switch reminder.action {
            case .shutdown:
                self?.requestSystemShutdown()
            case .none:
                break
            }
        }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: panel)
    }

    private func requestSystemShutdown() {
        guard let script = NSAppleScript(source: #"tell application "System Events" to shut down"#) else {
            showError("无法创建关机脚本。")
            return
        }

        var error: NSDictionary?
        script.executeAndReturnError(&error)

        if let error {
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "未知错误"
            showError(
                """
                无法执行系统关机：\(message)

                如果是首次使用，请在系统设置 > 隐私与安全性 > 自动化 中允许 \(AppMeta.displayName) 控制 System Events。
                """
            )
        }
    }

    @objc private func handleOpenDashboard() {
        guard let rawURL = store.currentSource.dashboardURL,
              let url = URL(string: rawURL) else {
            showError("控制台链接无效")
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func handleOpenPricing() {
        guard let url = URL(string: AppMeta.pricingURL) else {
            showError("购买链接无效")
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

private struct ScheduledTaskReminder {
    enum RepeatKind: String {
        case daily
        case weekly
        case monthly
    }

    let id: String
    let title: String
    let description: String
    let action: Action
    let repeatKind: RepeatKind
    let repeatDay: Int
    let hour: Int
    let minute: Int
    let cancelButtonTitle: String
    let confirmButtonTitle: String
    let iconImage: NSImage?

    enum Action: String {
        case none
        case shutdown
    }

    static func fromDefaults(
        _ defaults: UserDefaults = .standard,
        requireEnabled: Bool
    ) -> [ScheduledTaskReminder] {
        ScheduledTaskItem.loadAll(from: defaults).compactMap { item -> ScheduledTaskReminder? in
            guard !requireEnabled || item.enabled else { return nil }
            guard item.reminderType == "popup" else { return nil }
            let repeatKind = RepeatKind(rawValue: item.repeatKind) ?? .daily
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let cancelButtonTitle = item.cancelButtonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let confirmButtonTitle = item.confirmButtonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let iconImage = item.iconImageDataBase64
                .flatMap { Data(base64Encoded: $0) }
                .flatMap { NSImage(data: $0) }

            return ScheduledTaskReminder(
                id: item.id,
                title: title.isEmpty ? "电脑在线摆烂中" : title,
                description: description.isEmpty ? "CPU 都快冒烟了，赶紧关机，放我一码吧 🙏" : description,
                action: Action(rawValue: item.action) ?? .none,
                repeatKind: repeatKind,
                repeatDay: Self.normalizedRepeatDay(item.repeatDay, repeatKind: repeatKind),
                hour: max(0, min(23, item.hour)),
                minute: max(0, min(59, item.minute)),
                cancelButtonTitle: cancelButtonTitle.isEmpty ? "再卷一会儿" : cancelButtonTitle,
                confirmButtonTitle: confirmButtonTitle.isEmpty ? "准点下班" : confirmButtonTitle,
                iconImage: iconImage
            )
        }
    }

    var informativeText: String {
        let body = description.isEmpty ? "该处理你的定时任务了。" : description
        return "\(body)\n\n提醒方式：弹窗提醒\n执行时间：\(repeatTimeText)"
    }

    var repeatTimeText: String {
        let timeText = String(format: "%02d:%02d", hour, minute)
        switch repeatKind {
        case .daily:
            return "每天 \(timeText)"
        case .weekly:
            return "每周\(Self.weekdayText(repeatDay)) \(timeText)"
        case .monthly:
            return "每月\(repeatDay)号 \(timeText)"
        }
    }

    func isDue(at date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.day, .weekday, .hour, .minute], from: date)
        guard components.hour == hour, components.minute == minute else { return false }

        switch repeatKind {
        case .daily:
            return true
        case .weekly:
            return components.weekday == calendarWeekday(from: repeatDay)
        case .monthly:
            return components.day == repeatDay
        }
    }

    func occurrenceID(at date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return [
            id,
            repeatKind.rawValue,
            "\(components.year ?? 0)",
            "\(components.month ?? 0)",
            "\(components.day ?? 0)",
            "\(components.hour ?? 0)",
            "\(components.minute ?? 0)",
        ].joined(separator: "-")
    }

    private static func normalizedRepeatDay(_ value: Int, repeatKind: RepeatKind) -> Int {
        switch repeatKind {
        case .daily:
            return 1
        case .weekly:
            return max(1, min(7, value))
        case .monthly:
            return max(1, min(31, value))
        }
    }

    private static func weekdayText(_ value: Int) -> String {
        switch max(1, min(7, value)) {
        case 1:
            return "一"
        case 2:
            return "二"
        case 3:
            return "三"
        case 4:
            return "四"
        case 5:
            return "五"
        case 6:
            return "六"
        default:
            return "日"
        }
    }

    private func calendarWeekday(from scheduledWeekday: Int) -> Int {
        scheduledWeekday == 7 ? 1 : scheduledWeekday + 1
    }
}

@MainActor
private final class ScheduledTaskReminderPanel: NSPanel {
    private let onConfirm: () -> Void

    init(reminder: ScheduledTaskReminder, onConfirm: @escaping () -> Void) {
        self.onConfirm = onConfirm
        let size = NSSize(width: 420, height: 124)
        let palette = ScheduledTaskReminderThemePalette.current()
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        appearance = palette.appearance
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true
        collectionBehavior = [.transient, .ignoresCycle]
        contentView = ScheduledTaskReminderContentView(
            reminder: reminder,
            palette: palette,
            onCancel: { [weak self] in
                self?.closeModalPanel()
            },
            onConfirm: { [weak self] in
                self?.confirmAndClose()
            }
        )
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            confirmAndClose()
        case 53:
            closeModalPanel()
        default:
            super.keyDown(with: event)
        }
    }

    private func confirmAndClose() {
        closeModalPanel()
        onConfirm()
    }

    private func closeModalPanel() {
        NSApp.stopModal()
        orderOut(nil)
    }
}

@MainActor
private final class ScheduledTaskReminderContentView: NSView {
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    init(
        reminder: ScheduledTaskReminder,
        palette: ScheduledTaskReminderThemePalette,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 124))
        wantsLayer = true
        layer?.backgroundColor = palette.bodyBackground.cgColor
        layer?.cornerRadius = 13
        layer?.borderColor = palette.border.cgColor
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        buildView(reminder, palette: palette)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    private func buildView(_ reminder: ScheduledTaskReminder, palette: ScheduledTaskReminderThemePalette) {
        let titleBar = NSView()
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = palette.titleBackground.cgColor
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleBar)

        let titleLabel = NSTextField(labelWithString: reminder.title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = palette.primaryText
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(titleLabel)

        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = palette.divider.cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider)

        let iconView = ReminderChipIconView(palette: palette, image: reminder.iconImage)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        let messageLabel = NSTextField(labelWithString: reminder.description)
        messageLabel.font = .systemFont(ofSize: 13.5, weight: .bold)
        messageLabel.textColor = palette.primaryText
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 2
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)

        let cancelButton = ReminderActionButton(
            title: reminder.cancelButtonTitle,
            fillColor: palette.secondaryButton,
            highlightColor: palette.secondaryButtonHighlight,
            borderColor: palette.secondaryButtonBorder,
            textColor: palette.buttonText,
            action: onCancel
        )
        let confirmButton = ReminderActionButton(
            title: reminder.confirmButtonTitle,
            fillColor: palette.primaryButton,
            highlightColor: palette.primaryButtonHighlight,
            borderColor: palette.primaryButtonBorder,
            textColor: palette.buttonText,
            action: onConfirm
        )

        let buttonStack = NSStackView(views: [cancelButton, confirmButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttonStack)

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.centerXAnchor.constraint(equalTo: titleBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleBar.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: titleBar.trailingAnchor, constant: -18),

            divider.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            iconView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 17),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 58),

            messageLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            messageLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 20),

            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 14),
            buttonStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            buttonStack.widthAnchor.constraint(equalToConstant: 178),
            buttonStack.heightAnchor.constraint(equalToConstant: 22),
        ])
    }
}

private final class ReminderActionButton: NSControl {
    private let titleLabel = NSTextField(labelWithString: "")
    private let fillColor: NSColor
    private let highlightColor: NSColor
    private let actionHandler: () -> Void
    private var isPressed = false {
        didSet {
            layer?.backgroundColor = (isPressed ? highlightColor : fillColor).cgColor
        }
    }

    init(
        title: String,
        fillColor: NSColor,
        highlightColor: NSColor,
        borderColor: NSColor,
        textColor: NSColor,
        action: @escaping () -> Void
    ) {
        self.fillColor = fillColor
        self.highlightColor = highlightColor
        actionHandler = action
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = fillColor.cgColor
        layer?.cornerRadius = 6
        layer?.borderColor = borderColor.cgColor
        layer?.borderWidth = 0.6
        layer?.masksToBounds = true

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 12.5, weight: .bold)
        titleLabel.textColor = textColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -0.5),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let shouldTrigger = bounds.contains(location)
        isPressed = false
        if shouldTrigger {
            actionHandler()
        }
    }
}

private final class ReminderChipIconView: NSView {
    private let palette: ScheduledTaskReminderThemePalette
    private let image: NSImage?

    init(palette: ScheduledTaskReminderThemePalette, image: NSImage?) {
        self.palette = palette
        self.image = image
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let image {
            image.draw(
                in: aspectFitRect(for: image.size, inside: NSRect(x: 2, y: 2, width: bounds.width - 4, height: bounds.height - 4)),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return
        }

        let chipRect = NSRect(x: 10, y: 28, width: 46, height: 24)
        let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: 4, yRadius: 4)
        palette.iconChipFill.setFill()
        chipPath.fill()
        palette.iconChipStroke.setStroke()
        chipPath.lineWidth = 1.2
        chipPath.stroke()

        palette.iconPin.setStroke()
        for index in 0..<5 {
            let x = chipRect.minX + 7 + CGFloat(index) * 8
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: chipRect.maxY))
            path.line(to: NSPoint(x: x - 4, y: chipRect.maxY + 7))
            path.lineWidth = 1.6
            path.stroke()
        }

        let smoke = NSBezierPath()
        smoke.appendOval(in: NSRect(x: 17, y: 16, width: 15, height: 13))
        smoke.appendOval(in: NSRect(x: 27, y: 12, width: 17, height: 16))
        smoke.appendOval(in: NSRect(x: 37, y: 17, width: 13, height: 12))
        smoke.appendOval(in: NSRect(x: 24, y: 23, width: 21, height: 13))
        palette.iconSmokeFill.setFill()
        smoke.fill()
        palette.iconSmokeStroke.setStroke()
        smoke.lineWidth = 1
        smoke.stroke()

        let stemPath = NSBezierPath()
        stemPath.move(to: NSPoint(x: chipRect.midX, y: chipRect.minY + 4))
        stemPath.curve(
            to: NSPoint(x: 34, y: 24),
            controlPoint1: NSPoint(x: 28, y: 26),
            controlPoint2: NSPoint(x: 35, y: 28)
        )
        palette.iconSmokeStroke.setStroke()
        stemPath.lineWidth = 2
        stemPath.stroke()
    }

    private func aspectFitRect(for imageSize: NSSize, inside rect: NSRect) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0, rect.width > 0, rect.height > 0 else {
            return rect
        }

        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return NSRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }
}

private struct ScheduledTaskReminderThemePalette {
    let appearance: NSAppearance
    let titleBackground: NSColor
    let bodyBackground: NSColor
    let border: NSColor
    let divider: NSColor
    let primaryText: NSColor
    let secondaryButton: NSColor
    let secondaryButtonHighlight: NSColor
    let secondaryButtonBorder: NSColor
    let primaryButton: NSColor
    let primaryButtonHighlight: NSColor
    let primaryButtonBorder: NSColor
    let buttonText: NSColor
    let iconChipFill: NSColor
    let iconChipStroke: NSColor
    let iconPin: NSColor
    let iconSmokeFill: NSColor
    let iconSmokeStroke: NSColor

    @MainActor
    static func current(defaults: UserDefaults = .standard) -> ScheduledTaskReminderThemePalette {
        let rawSource = defaults.string(forKey: "skin_source_option") ?? "official"
        let rawTheme = defaults.string(forKey: "skin_theme_option") ?? "defaultFollowSystem"
        let customHue = defaults.object(forKey: "skin_custom_hue") as? Double ?? 0
        let customBrightness = defaults.object(forKey: "skin_custom_brightness") as? Double ?? 1
        let isCustom = rawSource == "vipCustom"
        let isDark: Bool
        if isCustom {
            isDark = true
        } else {
            switch rawTheme {
            case "ivoryWhite":
                isDark = false
            case "coolBlack":
                isDark = true
            default:
                isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
        }

        if isCustom {
            let baseBrightness = max(0.12, min(0.92, customBrightness))
            let saturation: CGFloat = customBrightness <= 0.02 ? 0 : 0.30
            let accentSaturation: CGFloat = customBrightness <= 0.02 ? 0 : 0.78
            let accentBrightness = max(0.42, min(1, baseBrightness))
            let accent = NSColor(
                calibratedHue: CGFloat(max(0, min(1, customHue))),
                saturation: accentSaturation,
                brightness: accentBrightness,
                alpha: 1
            )
            let body = NSColor(
                calibratedHue: CGFloat(max(0, min(1, customHue))),
                saturation: saturation,
                brightness: max(0.02, min(1, baseBrightness * 0.13)),
                alpha: 1
            )
            let title = NSColor(
                calibratedHue: CGFloat(max(0, min(1, customHue))),
                saturation: saturation,
                brightness: max(0.03, min(1, baseBrightness * 0.18)),
                alpha: 1
            )
            return ScheduledTaskReminderThemePalette(
                appearance: NSAppearance(named: .darkAqua) ?? NSApp.effectiveAppearance,
                titleBackground: title,
                bodyBackground: body,
                border: accent.withAlphaComponent(0.42),
                divider: NSColor.black.withAlphaComponent(0.42),
                primaryText: NSColor(white: 0.92, alpha: 1),
                secondaryButton: NSColor.white.withAlphaComponent(0.22),
                secondaryButtonHighlight: NSColor.white.withAlphaComponent(0.30),
                secondaryButtonBorder: NSColor.white.withAlphaComponent(0.16),
                primaryButton: accent,
                primaryButtonHighlight: accent.blended(withFraction: 0.12, of: .white) ?? accent,
                primaryButtonBorder: accent.blended(withFraction: 0.18, of: .white)?.withAlphaComponent(0.55) ?? accent.withAlphaComponent(0.55),
                buttonText: .white,
                iconChipFill: accent.withAlphaComponent(0.24),
                iconChipStroke: accent.withAlphaComponent(0.88),
                iconPin: accent.withAlphaComponent(0.88),
                iconSmokeFill: NSColor.white.withAlphaComponent(0.90),
                iconSmokeStroke: NSColor(white: 0.18, alpha: 0.78)
            )
        }

        if isDark {
            return ScheduledTaskReminderThemePalette(
                appearance: NSAppearance(named: .darkAqua) ?? NSApp.effectiveAppearance,
                titleBackground: NSColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1),
                bodyBackground: NSColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1),
                border: NSColor(red: 0.40, green: 0.40, blue: 0.42, alpha: 1),
                divider: NSColor.black.withAlphaComponent(0.35),
                primaryText: NSColor(white: 0.88, alpha: 1),
                secondaryButton: NSColor(red: 0.40, green: 0.40, blue: 0.42, alpha: 1),
                secondaryButtonHighlight: NSColor(red: 0.46, green: 0.46, blue: 0.48, alpha: 1),
                secondaryButtonBorder: NSColor.white.withAlphaComponent(0.10),
                primaryButton: NSColor(red: 0.20, green: 0.42, blue: 0.84, alpha: 1),
                primaryButtonHighlight: NSColor(red: 0.25, green: 0.48, blue: 0.92, alpha: 1),
                primaryButtonBorder: NSColor.white.withAlphaComponent(0.10),
                buttonText: .white,
                iconChipFill: NSColor(red: 0.86, green: 0.67, blue: 0.36, alpha: 1),
                iconChipStroke: NSColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 1),
                iconPin: NSColor(red: 0.95, green: 0.72, blue: 0.31, alpha: 1),
                iconSmokeFill: NSColor(white: 0.92, alpha: 1),
                iconSmokeStroke: NSColor(white: 0.10, alpha: 0.78)
            )
        }

        return ScheduledTaskReminderThemePalette(
            appearance: NSAppearance(named: .aqua) ?? NSApp.effectiveAppearance,
            titleBackground: NSColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1),
            bodyBackground: NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1),
            border: NSColor(red: 0.76, green: 0.78, blue: 0.82, alpha: 1),
            divider: NSColor.black.withAlphaComponent(0.10),
            primaryText: NSColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1),
            secondaryButton: NSColor(red: 0.72, green: 0.74, blue: 0.78, alpha: 1),
            secondaryButtonHighlight: NSColor(red: 0.64, green: 0.66, blue: 0.70, alpha: 1),
            secondaryButtonBorder: NSColor.black.withAlphaComponent(0.10),
            primaryButton: NSColor(red: 0.18, green: 0.39, blue: 0.82, alpha: 1),
            primaryButtonHighlight: NSColor(red: 0.23, green: 0.46, blue: 0.90, alpha: 1),
            primaryButtonBorder: NSColor.black.withAlphaComponent(0.06),
            buttonText: .white,
            iconChipFill: NSColor(red: 0.93, green: 0.76, blue: 0.42, alpha: 1),
            iconChipStroke: NSColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 1),
            iconPin: NSColor(red: 0.82, green: 0.54, blue: 0.18, alpha: 1),
            iconSmokeFill: NSColor(white: 0.97, alpha: 1),
            iconSmokeStroke: NSColor(white: 0.14, alpha: 0.75)
        )
    }
}
