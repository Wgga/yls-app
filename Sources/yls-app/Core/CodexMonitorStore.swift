import AppKit
import Foundation

@MainActor
final class CodexMonitorStore {
    var onStateChange: (() -> Void)?

    private let defaults: UserDefaults
    private let networkService: CodexMonitorNetworkServing

    private(set) var apiKey: String = ""
    private(set) var agiAPIKey: String = ""
    private(set) var currentSource: PackageSource = .codex
    private(set) var statisticsDisplayMode: StatisticsDisplayMode = .single
    private(set) var pollInterval: TimeInterval = 5
    private(set) var displayStyle: StatusDisplayStyle = .dailyRemainingAmount
    private(set) var statusBarForegroundMode: StatusBarForegroundMode = .autoAdapt
    private(set) var statusBarManualColorHex = AppMeta.defaultStatusBarColorHex
    private(set) var statusBarManualColor = NSColor.white
    private(set) var panelMode: MenuPanelMode = .statistics
    private(set) var statusFallbackText = "余额: --"
    private(set) var mcpEnabled = true
    private(set) var mcpPort: UInt16 = AppMeta.defaultMCPPort
    private(set) var launchAtLoginEnabled = true
    private(set) var sourceGroupExpanded: [PackageSource: Bool] = [
        .codex: true,
        .agi: true,
    ]

    private(set) var latestUsage = "--"
    private(set) var latestRemaining = "--"
    private(set) var latestDailyRemaining = "--"
    private(set) var latestWeeklyRemaining = "--"
    private(set) var latestRenewal = "--"
    private(set) var latestMessage = "等待数据"
    private(set) var latestUsageLabel = "已用/总"
    private(set) var latestProgressLabel = "用量进度"
    private(set) var latestProgressPrefix: String?
    private(set) var latestEmail: String?
    private(set) var latestPackageItems: [SummaryPackageItem] = []
    private(set) var latestUsedPercent: Double?
    private(set) var usageLogsPage: Int = 1
    private(set) var usageLogsPageSize: Int = 20
    private(set) var usageLogsPanel: CodexUsageRecordsPanelViewModel = .empty

    private(set) var agiLatestUsage = "--"
    private(set) var agiLatestRemaining = "--"
    private(set) var agiLatestRenewal = "--"
    private(set) var agiLatestMessage = ""
    private(set) var agiLatestPackageItems: [SummaryPackageItem] = []
    private(set) var agiLatestUsedPercent: Double?

    private(set) var isEmailVisible = false

    private var sourceStates: [PackageSource: SourceMonitorState] = [:]

    init(
        defaults: UserDefaults = .standard,
        networkService: CodexMonitorNetworkServing = CodexMonitorNetworkService()
    ) {
        self.defaults = defaults
        self.networkService = networkService
    }

    func loadConfiguration() {
        apiKey = defaults.string(forKey: DefaultsKey.codexAPIKey)
            ?? defaults.string(forKey: DefaultsKey.apiKey)
            ?? ""
        if defaults.object(forKey: DefaultsKey.agiAPIKey) != nil {
            agiAPIKey = defaults.string(forKey: DefaultsKey.agiAPIKey) ?? ""
        } else {
            agiAPIKey = ProcessInfo.processInfo.environment[AppMeta.agiEnvironmentKey] ?? ""
        }

        if let rawSource = defaults.string(forKey: DefaultsKey.selectedSource),
           let savedSource = PackageSource(rawValue: rawSource)
        {
            currentSource = savedSource
        }

        let rawStatisticsMode = defaults.integer(forKey: DefaultsKey.statisticsDisplayMode)
        statisticsDisplayMode = StatisticsDisplayMode(rawValue: rawStatisticsMode) ?? .single

        let interval = defaults.double(forKey: DefaultsKey.interval)
        if interval >= 1 {
            pollInterval = interval
        }

        let rawStyle = defaults.integer(forKey: DefaultsKey.displayStyle)
        displayStyle = StatusDisplayStyle(rawValue: rawStyle) ?? .dailyRemainingAmount

        if defaults.object(forKey: DefaultsKey.statusBarColorAutoAdapt) != nil {
            statusBarForegroundMode = defaults.bool(forKey: DefaultsKey.statusBarColorAutoAdapt) ? .autoAdapt : .manual
        } else {
            statusBarForegroundMode = .autoAdapt
        }

        if let colorHex = defaults.string(forKey: DefaultsKey.statusBarColorHex),
           let parsedColor = Self.colorFromHex(colorHex)
        {
            statusBarManualColor = parsedColor
            statusBarManualColorHex = Self.hexString(from: parsedColor)
        } else {
            statusBarManualColor = .white
            statusBarManualColorHex = AppMeta.defaultStatusBarColorHex
        }

        if defaults.object(forKey: DefaultsKey.mcpEnabled) != nil {
            mcpEnabled = defaults.bool(forKey: DefaultsKey.mcpEnabled)
        }
        let savedPort = defaults.integer(forKey: DefaultsKey.mcpPort)
        if let validPort = UInt16(exactly: savedPort), validPort > 0 {
            mcpPort = validPort
        }

        if defaults.object(forKey: DefaultsKey.launchAtLoginEnabled) != nil {
            launchAtLoginEnabled = defaults.bool(forKey: DefaultsKey.launchAtLoginEnabled)
        } else {
            launchAtLoginEnabled = true
        }

        rebuildSourceStates()
        syncLatestFieldsFromActiveSource()
    }

    func initializeStatusFallback() {
        rebuildSourceStates()
        syncLatestFieldsFromActiveSource()
        notifyStateChanged()
    }

    func setAPIKey(_ value: String) {
        setAPIKey(value, for: .codex)
    }

    func setAPIKey(_ value: String, for source: PackageSource) {
        let normalized = Self.normalizeAPIKey(value)
        switch source {
        case .codex:
            apiKey = normalized
        case .agi:
            agiAPIKey = normalized
            if agiAPIKey.isEmpty {
                sourceStates[.agi] = .placeholder(for: .agi, hasAPIKey: false)
            }
        }
        persistConfiguration()
        initializeStatusFallback()
        refreshNow()
    }

    func setAGIKey(_ value: String) {
        setAPIKey(value, for: .agi)
    }

    @discardableResult
    func setPollInterval(_ value: Double) -> Bool {
        guard value >= 1 else {
            return false
        }
        pollInterval = value
        persistConfiguration()
        notifyStateChanged()
        refreshNow()
        return true
    }

    func selectDisplayStyle(_ style: StatusDisplayStyle) {
        displayStyle = style
        persistConfiguration()
        notifyStateChanged()
    }

    func selectStatisticsDisplayMode(_ mode: StatisticsDisplayMode) {
        statisticsDisplayMode = mode
        persistConfiguration()
        syncLatestFieldsFromActiveSource()
        notifyStateChanged()
        refreshNow()
    }

    func selectSource(_ source: PackageSource) {
        currentSource = source
        isEmailVisible = false
        persistConfiguration()
        syncLatestFieldsFromActiveSource()
        notifyStateChanged()
        refreshNow()
    }

    func toggleSourceGroup(_ source: PackageSource) {
        sourceGroupExpanded[source] = !(sourceGroupExpanded[source] ?? true)
        notifyStateChanged()
    }

    func togglePanelMode() {
        panelMode = panelMode == .statistics ? .settings : .statistics
        notifyStateChanged()
    }

    func toggleEmailVisibility() {
        guard state(for: currentSource).email?.isEmpty == false else { return }
        isEmailVisible.toggle()
        notifyStateChanged()
    }

    func hideEmail() {
        guard isEmailVisible else { return }
        isEmailVisible = false
        notifyStateChanged()
    }

    func setMCPConfiguration(enabled: Bool, port: UInt16) {
        mcpEnabled = enabled
        mcpPort = port
        persistConfiguration()
        notifyStateChanged()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginEnabled = enabled
        persistConfiguration()
        notifyStateChanged()
    }

    func setStatusBarColor(mode: StatusBarForegroundMode, color: NSColor) {
        statusBarForegroundMode = mode
        statusBarManualColor = color
        statusBarManualColorHex = Self.hexString(from: color)
        persistConfiguration()
        notifyStateChanged()
    }

    func refreshNow() {
        Task { @MainActor in
            async let codexRefresh: Void = refreshCodexNow()
            async let agiRefresh: Void = refreshAGINow()
            async let logsRefresh: Void = refreshCodexUsageLogsNow(page: usageLogsPage)
            _ = await (codexRefresh, agiRefresh, logsRefresh)
        }
    }

    func selectUsageLogsPage(_ page: Int) {
        let normalized = max(1, page)
        guard normalized != usageLogsPage else { return }
        usageLogsPage = normalized
        notifyStateChanged()
        Task { @MainActor in
            await refreshCodexUsageLogsNow(page: normalized)
        }
    }

    func makeSummaryModel(
        supportsLaunchAtLogin: Bool,
        launchAtLoginUnavailableReason: String?,
        mcpStatusText: String
    ) -> StatusSummaryViewModel {
        let activeState = state(for: currentSource)
        let codexState = state(for: .codex)
        let codexDashboard = Self.buildCodexDashboardMetrics(
            dailyUsage: codexState.dailyUsagePayload,
            weeklyUsage: codexState.weeklyUsagePayload
        )
        let progressValue: String
        if let usedPercent = activeState.usedPercent {
            progressValue = String(format: "%.2f%%", max(0, min(100, usedPercent)))
        } else {
            progressValue = "--"
        }

        let displayEmail: String
        if let email = activeState.email, !email.isEmpty {
            displayEmail = isEmailVisible ? email : "***"
        } else {
            displayEmail = "--"
        }

        let (statusText, statusTone) = statisticsDisplayMode == .dual
            ? aggregateSummaryStatus()
            : summaryStatus(for: currentSource)
        let renewalLabel = activeState.packageItems.count > 1 ? "最近到期" : "下次续费 / 到期"
        let packageSectionTitle: String? = if activeState.packageItems.isEmpty {
            nil
        } else {
            activeState.packageItems.count == 1
                ? "当前\(currentSource.settingsTitle)套餐"
                : "\(currentSource.settingsTitle)有效套餐（\(activeState.packageItems.count)）"
        }
        let sourceGroups = PackageSource.allCases.map { source -> SourceSummaryGroupViewModel in
            let sourceState = state(for: source)
            let status = summaryStatus(for: source)
            let progressValue = sourceState.usedPercent.map {
                String(format: "%.2f%%", max(0, min(100, $0)))
            } ?? "--"
            let renewalLabel = sourceState.packageItems.count > 1 ? "最近到期" : "下次续费 / 到期"
            let footerText = sourceState.message.hasPrefix("更新时间:") ? "" : sourceState.message

            return SourceSummaryGroupViewModel(
                source: source,
                statusText: status.0,
                statusTone: status.1,
                usageLabel: sourceState.usageLabel,
                usageValue: sourceState.usage,
                remainingValue: sourceState.remaining,
                renewalLabel: renewalLabel,
                renewalValue: sourceState.renewal,
                packageItems: sourceState.packageItems,
                progressLabel: sourceState.progressLabel,
                progressPrefix: sourceState.progressPrefix,
                progressValue: progressValue,
                progress: sourceState.usedPercent.map { max(0, min(100, $0)) / 100 },
                footerText: footerText,
                isExpanded: sourceGroupExpanded[source] ?? true
            )
        }

        return StatusSummaryViewModel(
            title: AppMeta.displayName,
            currentSource: currentSource,
            currentSourceTitle: currentSource.chipTitle,
            statisticsDisplayMode: statisticsDisplayMode,
            statisticsModeText: statisticsDisplayMode.fullTitle,
            statusText: statusText,
            statusTone: statusTone,
            emailText: displayEmail,
            canToggleEmail: activeState.email?.isEmpty == false,
            isEmailVisible: isEmailVisible,
            usageLabel: activeState.usageLabel,
            usageValue: activeState.usage,
            remainingValue: activeState.remaining,
            renewalLabel: renewalLabel,
            renewalValue: activeState.renewal,
            packageSectionTitle: packageSectionTitle,
            packageItems: activeState.packageItems,
            progressLabel: activeState.progressLabel,
            progressPrefix: activeState.progressPrefix,
            progressValue: progressValue,
            progress: activeState.usedPercent.map { max(0, min(100, $0)) / 100 },
            footerText: activeState.message,
            hasAPIKey: !apiKey.isEmpty,
            hasAGIKey: !agiAPIKey.isEmpty,
            codexAPIKeyStatusText: apiKeyStatusText(for: .codex),
            agiAPIKeyStatusText: apiKeyStatusText(for: .agi),
            codexAPIKeyMaskedText: Self.maskedAPIKey(apiKey),
            agiAPIKeyMaskedText: Self.maskedAPIKey(agiAPIKey),
            pollIntervalSeconds: pollInterval,
            pollIntervalText: "\(Int(pollInterval)) 秒",
            launchAtLoginEnabled: launchAtLoginEnabled,
            launchAtLoginSupported: supportsLaunchAtLogin,
            launchAtLoginUnavailableReason: launchAtLoginUnavailableReason,
            displayStyle: displayStyle,
            statusBarForegroundMode: statusBarForegroundMode,
            statusBarManualColorHex: statusBarManualColorHex,
            statusBarColorText: currentStatusBarColorText(),
            panelMode: panelMode,
            mcpStatusText: mcpStatusText,
            mcpEnabled: mcpEnabled,
            mcpPort: mcpPort,
            canOpenDashboard: currentSource.dashboardURL != nil,
            canOpenPricing: currentSource.pricingURL != nil,
            dashboardActionTitle: currentSource.openDashboardTitle,
            sourceGroups: sourceGroups,
            mountedModules: [],
            codexDashboard: codexDashboard,
            codexUsageRecords: usageLogsPanel
        )
    }

    func makeMCPSnapshotData(mcpStatusText: String) -> Data {
        let activeState = state(for: currentSource)
        let snapshot = MCPServerSnapshot(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            displayName: AppMeta.displayName,
            dashboardURL: currentSource.dashboardURL ?? "",
            pricingURL: currentSource.pricingURL ?? "",
            currentSource: currentSource.rawValue,
            statisticsDisplayMode: statisticsDisplayMode.title,
            statusText: (statisticsDisplayMode == .dual ? aggregateSummaryStatus() : summaryStatus(for: currentSource)).0,
            latestMessage: activeState.message,
            remaining: activeState.remaining,
            usage: activeState.usage,
            renewal: activeState.renewal,
            progressLabel: activeState.progressLabel,
            progressPrefix: activeState.progressPrefix,
            usedPercent: activeState.usedPercent,
            email: activeState.email,
            hasAPIKey: !apiKey.isEmpty,
            hasAGIKey: !agiAPIKey.isEmpty,
            pollIntervalSeconds: pollInterval,
            displayStyle: displayStyle.title,
            packageItems: activeState.packageItems.map {
                MCPPackageItem(title: $0.title, subtitle: $0.subtitle, badgeText: $0.badgeText)
            },
            sourceGroups: PackageSource.allCases.map { source in
                let sourceState = state(for: source)
                let status = summaryStatus(for: source)
                return MCPSourceGroup(
                    source: source.rawValue,
                    statusText: status.0,
                    remaining: sourceState.remaining,
                    usage: sourceState.usage,
                    renewal: sourceState.renewal,
                    progressValue: sourceState.usedPercent.map { String(format: "%.2f%%", max(0, min(100, $0))) } ?? "--",
                    progressFraction: sourceState.usedPercent.map { max(0, min(100, $0)) / 100 },
                    packageItems: sourceState.packageItems.map {
                        MCPPackageItem(title: $0.title, subtitle: $0.subtitle, badgeText: $0.badgeText)
                    }
                )
            }
        )
        return (try? JSONEncoder().encode(snapshot)) ?? Data("{}".utf8)
    }

    private func persistConfiguration() {
        defaults.set(apiKey, forKey: DefaultsKey.apiKey)
        defaults.set(apiKey, forKey: DefaultsKey.codexAPIKey)
        defaults.set(agiAPIKey, forKey: DefaultsKey.agiAPIKey)
        defaults.set(currentSource.rawValue, forKey: DefaultsKey.selectedSource)
        defaults.set(statisticsDisplayMode.rawValue, forKey: DefaultsKey.statisticsDisplayMode)
        defaults.set(pollInterval, forKey: DefaultsKey.interval)
        defaults.set(displayStyle.rawValue, forKey: DefaultsKey.displayStyle)
        defaults.set(statusBarForegroundMode == .autoAdapt, forKey: DefaultsKey.statusBarColorAutoAdapt)
        defaults.set(statusBarManualColorHex, forKey: DefaultsKey.statusBarColorHex)
        defaults.set(mcpEnabled, forKey: DefaultsKey.mcpEnabled)
        defaults.set(Int(mcpPort), forKey: DefaultsKey.mcpPort)
        defaults.set(launchAtLoginEnabled, forKey: DefaultsKey.launchAtLoginEnabled)
    }

    private func refreshCodexNow() async {
        guard !apiKey.isEmpty else {
            updateStatusBar(text: "余额: 未配置Key")
            updateMenu(usage: "--", remaining: "--", message: "请先设置 API Key", usedPercent: nil, email: nil)
            return
        }

        let request = CodexUsageInfoRequestViewModel(apiKey: apiKey)

        do {
            let response = try await networkService.fetchCodexUsageInfo(using: request)
            updateStatusBar(text: "日余：\(response.state.dailyRemainingText)")
            updateMenu(
                usage: response.state.usageText,
                remaining: response.state.remainingText,
                dailyRemaining: response.state.dailyRemainingText,
                weeklyRemaining: response.state.weeklyRemainingText,
                message: "更新时间: \(Self.timeFormatter.string(from: Date()))",
                usedPercent: response.state.usedPercent,
                email: response.state.email,
                renewal: response.state.renewalText,
                packageItems: response.state.packageItems,
                usageLabel: response.state.usageLabel,
                progressLabel: response.state.progressLabel,
                progressPrefix: response.state.progressPrefix,
                dailyUsagePayload: response.state.dailyUsagePayload,
                weeklyUsagePayload: response.state.weeklyUsagePayload
            )
        } catch {
            handleCodexRequestFailure(error)
        }
    }

    private func refreshAGINow() async {
        guard !agiAPIKey.isEmpty else {
            resetAGIState(message: "")
            return
        }

        let request = AGIPackageInfoRequestViewModel(apiKey: agiAPIKey)

        do {
            let response = try await networkService.fetchAGIPackageInfo(using: request)
            updateAGIMenu(
                usage: response.state.usageText,
                remaining: response.state.remainingText,
                message: "更新时间: \(Self.timeFormatter.string(from: Date()))",
                usedPercent: response.state.usedPercent,
                renewal: response.state.renewalText,
                packageItems: response.state.packageItems
            )
        } catch {
            handleAGIRequestFailure(error)
        }
    }

    private func refreshCodexUsageLogsNow(page: Int) async {
        let normalizedPage = max(1, page)
        guard !apiKey.isEmpty else {
            usageLogsPanel = .error("请先设置 API Key", page: normalizedPage, pageSize: usageLogsPageSize)
            notifyStateChanged()
            return
        }

        let request = CodexUsageLogsRequestViewModel(
            apiKey: apiKey,
            page: normalizedPage,
            pageSize: usageLogsPageSize
        )

        do {
            let response = try await networkService.fetchCodexUsageLogs(using: request)
            usageLogsPage = response.state.panel.page
            usageLogsPageSize = response.state.panel.pageSize
            usageLogsPanel = response.state.panel
            notifyStateChanged()
        } catch {
            usageLogsPanel = .error(
                usageLogsErrorMessage(error),
                page: normalizedPage,
                pageSize: usageLogsPageSize
            )
            notifyStateChanged()
        }
    }

    private func usageLogsErrorMessage(_ error: Error) -> String {
        guard let networkError = error as? CodexMonitorNetworkError else {
            return "使用记录请求失败: \(error.localizedDescription)"
        }

        switch networkError {
        case .invalidHTTPResponse:
            return "使用记录响应异常"
        case .httpStatus(_, let statusCode):
            return "使用记录接口 HTTP \(statusCode)"
        case .business(_, let code, let message):
            return "使用记录错误码 \(code): \(message)"
        case .unauthorized(_, let message):
            return message
        case .missingField(_, let field):
            return "使用记录响应缺少 \(field) 字段"
        case .decoding(_, let message, _):
            return "使用记录解析错误: \(message)"
        case .transport(_, let message):
            return "使用记录网络错误: \(message)"
        }
    }

    private func handleCodexRequestFailure(_ error: Error) {
        guard let networkError = error as? CodexMonitorNetworkError else {
            updateStatusBar(text: "余额: 请求失败")
            updateMenu(
                usage: "--",
                remaining: "--",
                message: "网络错误: \(error.localizedDescription)",
                usedPercent: nil,
                email: nil
            )
            return
        }

        switch networkError {
        case .invalidHTTPResponse:
            updateStatusBar(text: "余额: 响应异常")
            updateMenu(usage: "--", remaining: "--", message: "无效响应", usedPercent: nil, email: nil)
        case .httpStatus(_, let statusCode):
            updateStatusBar(text: "余额: HTTP \(statusCode)")
            updateMenu(
                usage: "--",
                remaining: "--",
                message: "接口返回 HTTP \(statusCode)",
                usedPercent: nil,
                email: nil
            )
        case .business(_, let code, let message):
            updateStatusBar(text: "余额: 业务错误")
            updateMenu(
                usage: "--",
                remaining: "--",
                message: "错误码 \(code): \(message)",
                usedPercent: nil,
                email: nil
            )
        case .unauthorized(_, let message):
            updateStatusBar(text: "余额: 授权错误")
            updateMenu(
                usage: "--",
                remaining: "--",
                message: message,
                usedPercent: nil,
                email: nil
            )
        case .missingField(_, let field):
            updateStatusBar(text: "余额: 响应异常")
            updateMenu(
                usage: "--",
                remaining: "--",
                message: "响应里缺少 \(field) 字段",
                usedPercent: nil,
                email: nil
            )
        case .decoding(_, let message, let snippet):
            let rawSnippet = snippet ?? "无法读取响应内容"
            updateStatusBar(text: "余额: 解析失败")
            updateMenu(
                usage: "--",
                remaining: "--",
                message: "解析错误: \(message) | \(rawSnippet)",
                usedPercent: nil,
                email: nil
            )
        case .transport(_, let message):
            updateStatusBar(text: "余额: 请求失败")
            updateMenu(
                usage: "--",
                remaining: "--",
                message: "网络错误: \(message)",
                usedPercent: nil,
                email: nil
            )
        }
    }

    private func handleAGIRequestFailure(_ error: Error) {
        guard let networkError = error as? CodexMonitorNetworkError else {
            updateAGIMenu(
                usage: "--",
                remaining: "--",
                message: "AGI 网络错误: \(error.localizedDescription)",
                usedPercent: nil
            )
            return
        }

        switch networkError {
        case .invalidHTTPResponse:
            updateAGIMenu(usage: "--", remaining: "--", message: "AGI 响应异常", usedPercent: nil)
        case .httpStatus(_, let statusCode):
            updateAGIMenu(
                usage: "--",
                remaining: "--",
                message: "AGI 接口 HTTP \(statusCode)",
                usedPercent: nil
            )
        case .business(_, let code, let message):
            updateAGIMenu(
                usage: "--",
                remaining: "--",
                message: "AGI 错误码 \(code): \(message)",
                usedPercent: nil
            )
        case .unauthorized(_, let message):
            updateAGIMenu(
                usage: "--",
                remaining: "--",
                message: "AGI 授权错误: \(message)",
                usedPercent: nil
            )
        case .missingField(_, let field):
            updateAGIMenu(
                usage: "--",
                remaining: "--",
                message: "AGI 响应缺少 \(field) 字段",
                usedPercent: nil
            )
        case .decoding(_, let message, let snippet):
            let rawSnippet = snippet ?? "无法读取响应内容"
            updateAGIMenu(
                usage: "--",
                remaining: "--",
                message: "AGI 解析错误: \(message) | \(rawSnippet)",
                usedPercent: nil
            )
        case .transport(_, let message):
            updateAGIMenu(
                usage: "--",
                remaining: "--",
                message: "AGI 网络错误: \(message)",
                usedPercent: nil
            )
        }
    }

    private func updateStatusBar(text: String) {
        statusFallbackText = text
        notifyStateChanged()
    }

    private func updateMenu(
        usage: String,
        remaining: String,
        dailyRemaining: String? = nil,
        weeklyRemaining: String? = nil,
        message: String,
        usedPercent: Double?,
        email: String?,
        renewal: String = "--",
        packageItems: [SummaryPackageItem] = [],
        usageLabel: String = "已用/总",
        progressLabel: String = "用量进度",
        progressPrefix: String? = nil,
        dailyUsagePayload: UsagePayload? = nil,
        weeklyUsagePayload: UsagePayload? = nil
    ) {
        var state = state(for: .codex)
        let resolvedDailyRemaining = dailyRemaining ?? dailyUsagePayload?.remainingQuota?.display ?? "--"
        state.usage = usage
        state.remaining = remaining
        state.renewal = renewal
        state.message = message
        state.usageLabel = usageLabel
        state.progressLabel = progressLabel
        state.progressPrefix = progressPrefix
        state.email = email
        state.packageItems = packageItems
        state.usedPercent = usedPercent
        state.dailyRemaining = resolvedDailyRemaining
        state.dailyUsagePayload = dailyUsagePayload
        state.weeklyUsagePayload = weeklyUsagePayload
        state.fallbackText = resolvedDailyRemaining == "--" ? statusFallbackText : "日余：\(resolvedDailyRemaining)"
        sourceStates[.codex] = state

        latestUsage = usage
        latestRemaining = remaining
        latestDailyRemaining = resolvedDailyRemaining
        latestWeeklyRemaining = weeklyRemaining ?? "--"
        latestRenewal = renewal
        latestMessage = message
        latestUsageLabel = usageLabel
        latestProgressLabel = progressLabel
        latestProgressPrefix = progressPrefix
        latestEmail = email
        latestPackageItems = packageItems
        latestUsedPercent = usedPercent
        syncLatestFieldsFromActiveSource()
        notifyStateChanged()
    }

    private func updateAGIMenu(
        usage: String,
        remaining: String,
        message: String,
        usedPercent: Double?,
        renewal: String = "--",
        packageItems: [SummaryPackageItem] = []
    ) {
        var state = state(for: .agi)
        state.usage = usage
        state.remaining = remaining
        state.renewal = renewal
        state.message = message
        state.usageLabel = "已用/总字节"
        state.progressLabel = "AGI 用量进度"
        state.progressPrefix = nil
        state.email = nil
        state.packageItems = packageItems
        state.usedPercent = usedPercent
        state.dailyRemaining = nil
        state.dailyUsagePayload = nil
        state.weeklyUsagePayload = nil
        state.fallbackText = remaining == "--" ? "AGI: \(message.isEmpty ? "未配置Key" : "异常")" : "余: \(remaining)"
        sourceStates[.agi] = state

        agiLatestUsage = usage
        agiLatestRemaining = remaining
        agiLatestRenewal = renewal
        agiLatestMessage = message
        agiLatestPackageItems = packageItems
        agiLatestUsedPercent = usedPercent
        syncLatestFieldsFromActiveSource()
        notifyStateChanged()
    }

    private func resetAGIState(message: String) {
        sourceStates[.agi] = .placeholder(for: .agi, hasAPIKey: false)
        if !message.isEmpty {
            sourceStates[.agi]?.message = message
        }
        agiLatestUsage = "--"
        agiLatestRemaining = "--"
        agiLatestRenewal = "--"
        agiLatestMessage = message
        agiLatestPackageItems = []
        agiLatestUsedPercent = nil
        syncLatestFieldsFromActiveSource()
        notifyStateChanged()
    }

    func statusBarSnapshot() -> (
        dailyUsedAmount: String,
        dailyRemainingAmount: String,
        weeklyUsedAmount: String,
        weeklyRemainingAmount: String,
        dailyUsedPercent: Double?,
        weeklyUsedPercent: Double?,
        fallbackText: String
    ) {
        let source = primaryStatusSource()
        let sourceState = state(for: source)

        let dailyRemainingAmount = sourceState.dailyRemaining ?? sourceState.dailyUsagePayload?.remainingQuota?.display ?? "--"
        let weeklyRemainingAmount = sourceState.weeklyUsagePayload?.remainingQuota?.display ?? sourceState.remaining

        let dailyTotalQuota = sourceState.dailyUsagePayload?.totalQuota?.doubleValue
        let dailyRemainingQuota = sourceState.dailyUsagePayload?.remainingQuota?.doubleValue
        let dailyUsedQuota: Double?
        if let dailyTotalQuota, dailyTotalQuota > 0, let dailyRemainingQuota {
            dailyUsedQuota = max(0, dailyTotalQuota - dailyRemainingQuota)
        } else {
            dailyUsedQuota = sourceState.dailyUsagePayload?.totalCost?.doubleValue
        }
        let dailyUsedPercent = Self.resolveUsedPercentFromPayload(
            usage: sourceState.dailyUsagePayload,
            used: dailyUsedQuota,
            total: dailyTotalQuota
        )

        let dailyUsedAmount: String
        if let totalCostDisplay = sourceState.dailyUsagePayload?.totalCost?.display {
            dailyUsedAmount = totalCostDisplay
        } else if let dailyUsedQuota {
            dailyUsedAmount = Self.formatAmount(dailyUsedQuota)
        } else {
            dailyUsedAmount = "--"
        }

        let weeklyUsedAmount = sourceState.weeklyUsagePayload?.totalCost?.display ?? sourceState.usage

        return (
            dailyUsedAmount: dailyUsedAmount,
            dailyRemainingAmount: dailyRemainingAmount,
            weeklyUsedAmount: weeklyUsedAmount,
            weeklyRemainingAmount: weeklyRemainingAmount,
            dailyUsedPercent: dailyUsedPercent,
            weeklyUsedPercent: sourceState.usedPercent,
            fallbackText: sourceState.fallbackText
        )
    }

    private func rebuildSourceStates() {
        for source in PackageSource.allCases {
            let hasAPIKey = !apiKeyValue(for: source).isEmpty
            let existing = sourceStates[source]
            if let existing, existing.remaining != "--" {
                continue
            }
            sourceStates[source] = .placeholder(for: source, hasAPIKey: hasAPIKey)
        }
    }

    private func state(for source: PackageSource) -> SourceMonitorState {
        sourceStates[source] ?? .placeholder(for: source, hasAPIKey: !apiKeyValue(for: source).isEmpty)
    }

    private func syncLatestFieldsFromActiveSource() {
        let activeState = state(for: currentSource)
        latestUsage = activeState.usage
        latestRemaining = activeState.remaining
        latestRenewal = activeState.renewal
        latestMessage = activeState.message
        latestUsageLabel = activeState.usageLabel
        latestProgressLabel = activeState.progressLabel
        latestProgressPrefix = activeState.progressPrefix
        latestEmail = activeState.email
        latestPackageItems = activeState.packageItems
        latestUsedPercent = activeState.usedPercent
        statusFallbackText = statusBarSnapshot().fallbackText
    }

    private func apiKeyValue(for source: PackageSource) -> String {
        switch source {
        case .codex:
            return apiKey
        case .agi:
            return agiAPIKey
        }
    }

    private func apiKeyStatusText(for source: PackageSource) -> String {
        apiKeyValue(for: source).isEmpty ? "未配置" : "已配置"
    }

    private static func maskedAPIKey(_ apiKey: String) -> String {
        guard !apiKey.isEmpty else { return "" }
        return String(repeating: "•", count: apiKey.count)
    }

    private func primaryStatusSource() -> PackageSource {
        if statisticsDisplayMode == .dual {
            let codex = state(for: .codex)
            if codex.remaining != "--" || !apiKey.isEmpty {
                return .codex
            }
            let agi = state(for: .agi)
            if agi.remaining != "--" || !agiAPIKey.isEmpty {
                return .agi
            }
            return .codex
        }
        return currentSource
    }

    private func summaryStatus(for source: PackageSource) -> (String, SummaryStatusTone) {
        let sourceState = state(for: source)
        if sourceState.remaining != "--" {
            return ("在线", .success)
        }
        if sourceState.fallbackText.contains("未配置") || sourceState.message.contains("请先设置") {
            return ("未配置", .warning)
        }
        if sourceState.fallbackText.contains("加载中") {
            return ("加载中", .neutral)
        }
        if sourceState.fallbackText.contains("请求失败")
            || sourceState.fallbackText.contains("网络错误")
            || sourceState.fallbackText.contains("授权错误")
            || sourceState.fallbackText.contains("HTTP")
            || sourceState.fallbackText.contains("解析失败")
            || sourceState.fallbackText.contains("解析错误")
            || sourceState.fallbackText.contains("业务错误")
            || sourceState.fallbackText.contains("响应异常")
            || sourceState.message.contains("错误")
            || sourceState.message.contains("异常")
            || sourceState.message.contains("失败")
        {
            return ("异常", .critical)
        }
        return ("等待中", .neutral)
    }

    private func aggregateSummaryStatus() -> (String, SummaryStatusTone) {
        let statuses = PackageSource.allCases.map(summaryStatus(for:))
        if statuses.contains(where: { $0.1 == .success }) {
            return ("在线", .success)
        }
        if statuses.allSatisfy({ $0.1 == .warning }) {
            return ("未配置", .warning)
        }
        if statuses.contains(where: { $0.1 == .critical }) {
            return ("异常", .critical)
        }
        if statuses.contains(where: { $0.1 == .neutral }) {
            return ("加载中", .neutral)
        }
        return ("等待中", .neutral)
    }

    private func currentStatusBarColorText() -> String {
        if statusBarForegroundMode == .autoAdapt {
            return "自动适配（手动 \(statusBarManualColorHex)）"
        }
        return "手动 \(statusBarManualColorHex)"
    }

    private func notifyStateChanged() {
        onStateChange?()
    }

    private static func colorFromHex(_ rawValue: String) -> NSColor? {
        let cleaned = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard cleaned.count == 6, let packed = UInt32(cleaned, radix: 16) else {
            return nil
        }

        let red = CGFloat((packed >> 16) & 0xFF) / 255
        let green = CGFloat((packed >> 8) & 0xFF) / 255
        let blue = CGFloat(packed & 0xFF) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    private static func hexString(from color: NSColor) -> String {
        let converted = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB) ?? .white
        let red = Int(round(max(0, min(1, converted.redComponent)) * 255))
        let green = Int(round(max(0, min(1, converted.greenComponent)) * 255))
        let blue = Int(round(max(0, min(1, converted.blueComponent)) * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    nonisolated private static func normalizeAPIKey(_ rawValue: String) -> String {
        let components = rawValue
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !components.isEmpty else { return "" }
        if components[0].lowercased() == "bearer" {
            return components.dropFirst().first ?? ""
        }
        return components[0]
    }

    nonisolated private static func buildCodexDashboardMetrics(
        dailyUsage: UsagePayload?,
        weeklyUsage: UsagePayload?
    ) -> CodexDashboardMetrics {
        let dailyUsedQuota = dailyUsage?.totalCost?.doubleValue
        let dailyTotalQuota = dailyUsage?.totalQuota?.doubleValue
        let weeklyUsedQuota = weeklyUsage?.totalCost?.doubleValue
        let weeklyTotalQuota = weeklyUsage?.totalQuota?.doubleValue

        return CodexDashboardMetrics(
            dailyUsedQuota: dailyUsedQuota,
            dailyTotalQuota: dailyTotalQuota,
            dailyUsedPercent: resolveUsedPercentFromPayload(usage: dailyUsage, used: dailyUsedQuota, total: dailyTotalQuota),
            weeklyUsedQuota: weeklyUsedQuota,
            weeklyTotalQuota: weeklyTotalQuota,
            weeklyUsedPercent: resolveUsedPercentFromPayload(usage: weeklyUsage, used: weeklyUsedQuota, total: weeklyTotalQuota),
            requestCount: integerValue(dailyUsage?.requestCount),
            totalCost: dailyUsage?.totalCost?.doubleValue,
            totalTokens: dailyUsage?.totalTokens?.doubleValue,
            inputTokens: dailyUsage?.inputTokens?.doubleValue,
            cachedInputTokens: dailyUsage?.inputTokensCached?.doubleValue,
            outputTokens: dailyUsage?.outputTokens?.doubleValue
        )
    }

    nonisolated private static func resolveUsedPercentFromPayload(
        usage: UsagePayload?,
        used: Double?,
        total: Double?
    ) -> Double? {
        if let percent = usage?.usedPercentage?.doubleValue, percent.isFinite {
            return min(max(percent, 0), 100)
        }
        guard let used, let total, total > 0 else { return nil }
        let percent = (used / total) * 100
        guard percent.isFinite else { return nil }
        return min(max(percent, 0), 100)
    }

    nonisolated private static func formatAmount(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        var text = String(format: "%.2f", value)
        while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
            text.removeLast()
        }
        return text
    }

    nonisolated private static func integerValue(_ number: FlexibleNumber?) -> Int? {
        guard let raw = number?.doubleValue, raw.isFinite else { return nil }
        return Int(raw.rounded())
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
