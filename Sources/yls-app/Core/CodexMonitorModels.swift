import AppKit
import Foundation
import SwiftUI

enum DefaultsKey {
    static let apiKey = "api_key"
    static let codexAPIKey = "codex_api_key"
    static let agiAPIKey = "agi_api_key"
    static let selectedSource = "selected_source"
    static let statisticsDisplayMode = "statistics_display_mode"
    static let interval = "poll_interval_seconds"
    static let displayStyle = "status_display_style"
    static let statusBarColorAutoAdapt = "status_bar_color_auto_adapt"
    static let statusBarColorHex = "status_bar_color_hex"
    static let mcpEnabled = "mcp_enabled"
    static let mcpPort = "mcp_port"
    static let launchAtLoginEnabled = "launch_at_login_enabled"
    static let scheduledTaskConfigured = "scheduled_task_configured"
    static let scheduledTaskEnabled = "scheduled_task_enabled"
    static let scheduledTaskHour = "scheduled_task_hour"
    static let scheduledTaskMinute = "scheduled_task_minute"
    static let scheduledTaskRepeatKind = "scheduled_task_repeat_kind"
    static let scheduledTaskRepeatDay = "scheduled_task_repeat_day"
    static let scheduledTaskTitle = "scheduled_task_title"
    static let scheduledTaskDescription = "scheduled_task_description"
    static let scheduledTaskReminderType = "scheduled_task_reminder_type"
    static let scheduledTaskAction = "scheduled_task_action"
    static let scheduledTaskCancelButtonTitle = "scheduled_task_cancel_button_title"
    static let scheduledTaskConfirmButtonTitle = "scheduled_task_confirm_button_title"
    static let scheduledTasks = "scheduled_tasks"
    static let codexSwitchProviders = "codex_switch_providers"
}

extension Notification.Name {
    static let scheduledTaskReminderRequested = Notification.Name("scheduled_task_reminder_requested")
    static let scheduledTaskReminderConfigurationChanged = Notification.Name("scheduled_task_reminder_configuration_changed")
}

struct ScheduledTaskItem: Codable, Identifiable, Equatable {
    enum Action: String, Codable, CaseIterable {
        case none
        case shutdown
    }

    var id: String
    var enabled: Bool
    var title: String
    var description: String
    var reminderType: String
    var action: String
    var repeatKind: String
    var repeatDay: Int
    var hour: Int
    var minute: Int
    var cancelButtonTitle: String
    var confirmButtonTitle: String
    var iconImageDataBase64: String?

    init(
        id: String,
        enabled: Bool,
        title: String,
        description: String,
        reminderType: String,
        action: String,
        repeatKind: String,
        repeatDay: Int,
        hour: Int,
        minute: Int,
        cancelButtonTitle: String,
        confirmButtonTitle: String,
        iconImageDataBase64: String? = nil
    ) {
        self.id = id
        self.enabled = enabled
        self.title = title
        self.description = description
        self.reminderType = reminderType
        self.action = Self.normalizedAction(action)
        self.repeatKind = repeatKind
        self.repeatDay = repeatDay
        self.hour = hour
        self.minute = minute
        self.cancelButtonTitle = cancelButtonTitle
        self.confirmButtonTitle = confirmButtonTitle
        self.iconImageDataBase64 = iconImageDataBase64
    }

    enum CodingKeys: String, CodingKey {
        case id
        case enabled
        case title
        case description
        case reminderType
        case action
        case repeatKind
        case repeatDay
        case hour
        case minute
        case cancelButtonTitle
        case confirmButtonTitle
        case iconImageDataBase64
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        reminderType = try container.decode(String.self, forKey: .reminderType)
        repeatKind = try container.decode(String.self, forKey: .repeatKind)
        repeatDay = try container.decode(Int.self, forKey: .repeatDay)
        hour = try container.decode(Int.self, forKey: .hour)
        minute = try container.decode(Int.self, forKey: .minute)
        cancelButtonTitle = try container.decode(String.self, forKey: .cancelButtonTitle)
        confirmButtonTitle = try container.decode(String.self, forKey: .confirmButtonTitle)
        iconImageDataBase64 = try container.decodeIfPresent(String.self, forKey: .iconImageDataBase64)
        action = Self.normalizedAction(
            try container.decodeIfPresent(String.self, forKey: .action)
                ?? Self.inferredAction(title: title, description: description, confirmButtonTitle: confirmButtonTitle)
        )
    }

    static func loadAll(from defaults: UserDefaults = .standard) -> [ScheduledTaskItem] {
        if let data = defaults.data(forKey: DefaultsKey.scheduledTasks),
           let items = try? JSONDecoder().decode([ScheduledTaskItem].self, from: data)
        {
            return items
        }

        guard let legacy = legacyItem(from: defaults) else {
            return []
        }
        saveAll([legacy], to: defaults)
        return [legacy]
    }

    static func saveAll(_ items: [ScheduledTaskItem], to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: DefaultsKey.scheduledTasks)
        }
        defaults.set(!items.isEmpty, forKey: DefaultsKey.scheduledTaskConfigured)
    }

    private static func legacyItem(from defaults: UserDefaults) -> ScheduledTaskItem? {
        guard defaults.bool(forKey: DefaultsKey.scheduledTaskConfigured) else { return nil }
        return ScheduledTaskItem(
            id: UUID().uuidString,
            enabled: defaults.object(forKey: DefaultsKey.scheduledTaskEnabled) == nil
                ? true
                : defaults.bool(forKey: DefaultsKey.scheduledTaskEnabled),
            title: defaults.string(forKey: DefaultsKey.scheduledTaskTitle) ?? "",
            description: defaults.string(forKey: DefaultsKey.scheduledTaskDescription) ?? "",
            reminderType: defaults.string(forKey: DefaultsKey.scheduledTaskReminderType) ?? "popup",
            action: defaults.string(forKey: DefaultsKey.scheduledTaskAction) ?? inferredAction(
                title: defaults.string(forKey: DefaultsKey.scheduledTaskTitle) ?? "",
                description: defaults.string(forKey: DefaultsKey.scheduledTaskDescription) ?? "",
                confirmButtonTitle: defaults.string(forKey: DefaultsKey.scheduledTaskConfirmButtonTitle) ?? "准点下班"
            ),
            repeatKind: defaults.string(forKey: DefaultsKey.scheduledTaskRepeatKind) ?? "daily",
            repeatDay: max(1, defaults.integer(forKey: DefaultsKey.scheduledTaskRepeatDay)),
            hour: max(0, min(23, defaults.integer(forKey: DefaultsKey.scheduledTaskHour))),
            minute: max(0, min(59, defaults.integer(forKey: DefaultsKey.scheduledTaskMinute))),
            cancelButtonTitle: defaults.string(forKey: DefaultsKey.scheduledTaskCancelButtonTitle) ?? "再卷一会儿",
            confirmButtonTitle: defaults.string(forKey: DefaultsKey.scheduledTaskConfirmButtonTitle) ?? "准点下班"
        )
    }

    static func normalizedAction(_ value: String) -> String {
        Action(rawValue: value)?.rawValue ?? Action.none.rawValue
    }

    static func inferredAction(title: String, description: String, confirmButtonTitle: String) -> String {
        let source = "\(title) \(description)"
        return source.contains("关机") || source.contains("下班")
            ? Action.shutdown.rawValue
            : Action.none.rawValue
    }
}

struct CodexSwitchProviderItem: Codable, Identifiable, Equatable {
    enum Scope: String, Codable, CaseIterable {
        case appSpecific
        case universal

        var title: String {
            switch self {
            case .appSpecific:
                return "应用专属"
            case .universal:
                return "通用"
            }
        }
    }

    var id: String
    var scope: String
    var preset: String
    var name: String
    var endpoint: String
    var useFullURL: Bool
    var apiKey: String
    var website: String
    var notes: String

    init(
        id: String,
        scope: String,
        preset: String,
        name: String,
        endpoint: String,
        useFullURL: Bool = false,
        apiKey: String,
        website: String,
        notes: String
    ) {
        self.id = id
        self.scope = Self.normalizedScope(scope)
        self.preset = preset
        self.name = name
        self.endpoint = endpoint
        self.useFullURL = useFullURL
        self.apiKey = apiKey
        self.website = website
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case scope
        case preset
        case name
        case endpoint
        case useFullURL
        case apiKey
        case website
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        scope = Self.normalizedScope(try container.decode(String.self, forKey: .scope))
        preset = try container.decode(String.self, forKey: .preset)
        name = try container.decode(String.self, forKey: .name)
        endpoint = try container.decode(String.self, forKey: .endpoint)
        useFullURL = try container.decodeIfPresent(Bool.self, forKey: .useFullURL) ?? false
        apiKey = try container.decode(String.self, forKey: .apiKey)
        website = try container.decode(String.self, forKey: .website)
        notes = try container.decode(String.self, forKey: .notes)
    }

    static func loadAll(from defaults: UserDefaults = .standard) -> [CodexSwitchProviderItem] {
        if let data = defaults.data(forKey: DefaultsKey.codexSwitchProviders),
           let items = try? JSONDecoder().decode([CodexSwitchProviderItem].self, from: data)
        {
            return items
        }
        return []
    }

    static func saveAll(_ items: [CodexSwitchProviderItem], to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: DefaultsKey.codexSwitchProviders)
        }
    }

    static func normalizedScope(_ rawValue: String) -> String {
        Scope(rawValue: rawValue)?.rawValue ?? Scope.appSpecific.rawValue
    }
}

enum AppMeta {
    static let displayName = "伊莉思监控助手"
    static let codexEndpoint = URL(string: "https://code.ylsagi.com/codex/info")!
    static let codexLogsEndpoint = URL(string: "https://code.ylsagi.com/codex/logs")!
    static let agiPackageEndpoint = URL(string: "https://api.ylsagi.com/user/package")!
    static let agiEnvironmentKey = "YLS_AGI_KEY"
    static let dashboardURL = "https://code.ylsagi.com/user/dashboard"
    static let pricingURL = "https://code.ylsagi.com/pricing"
    static let mcpHost = "127.0.0.1"
    static let defaultMCPPort: UInt16 = 8765
    static let stackedStatusMinWidth: CGFloat = 44
    static let stackedStatusMaxWidth: CGFloat = 72
    static let stackedHorizontalPadding: CGFloat = 4
    static let stackedStatusHeight: CGFloat = 18
    static let stackedLineGap: CGFloat = 1
    static let stackedVerticalNudge: CGFloat = -0.5
    static let stackedTopFontSize: CGFloat = 9.5
    static let stackedBottomFontSize: CGFloat = 7.5
    static let circleMinWidth: CGFloat = 44
    static let circleMaxWidth: CGFloat = 76
    static let circleHorizontalPadding: CGFloat = 4
    static let circleBottomFontSize: CGFloat = 8
    static let circleLineGap: CGFloat = 1
    static let circleLineWidth: CGFloat = 1.8
    static let circleDiameter: CGFloat = 13
    static let defaultStatusBarColorHex = "#FFFFFF"
}

enum PackageSource: String, CaseIterable {
    case codex
    case agi

    var title: String {
        switch self {
        case .codex:
            return "Codex 套餐"
        case .agi:
            return "AGI 套餐"
        }
    }

    var chipTitle: String {
        switch self {
        case .codex:
            return "Codex"
        case .agi:
            return "AGI"
        }
    }

    var settingsTitle: String {
        switch self {
        case .codex:
            return "Codex"
        case .agi:
            return "AGI"
        }
    }

    var keyButtonTitle: String {
        switch self {
        case .codex:
            return "Codex API Key"
        case .agi:
            return "AGI API Key"
        }
    }

    var dashboardURL: String? {
        switch self {
        case .codex:
            return AppMeta.dashboardURL
        case .agi:
            return nil
        }
    }

    var pricingURL: String? {
        switch self {
        case .codex:
            return AppMeta.pricingURL
        case .agi:
            return nil
        }
    }

}

enum StatusDisplayStyle: Int, CaseIterable {
    case dailyRemainingAmount = 0
    case dailyRemainingCircle = 1
    case weeklyUsedPercent = 2
    case weeklyRemainingPercent = 3
    case weeklyUsedCircle = 4
    case weeklyRemainingCircle = 5
    case dailyUsedAmount = 6
    case dailyUsedCircle = 7
    case dailyUsedPercent = 8
    case dailyRemainingPercent = 9
    case weeklyUsedAmount = 10
    case weeklyRemainingAmount = 11

    enum TimeRange: String, CaseIterable {
        case daily
        case weekly

        var title: String {
            switch self {
            case .daily:
                return "每日"
            case .weekly:
                return "每周"
            }
        }

        var symbol: String {
            switch self {
            case .daily:
                return "sun.max"
            case .weekly:
                return "calendar"
            }
        }
    }

    enum MetricKind: String, CaseIterable {
        case used
        case remaining

        var title: String {
            switch self {
            case .used:
                return "用量"
            case .remaining:
                return "剩余"
            }
        }

        var symbol: String {
            switch self {
            case .used:
                return "arrow.up.forward"
            case .remaining:
                return "arrow.down.forward"
            }
        }
    }

    enum PresentationKind: String, CaseIterable {
        case amount
        case circle
        case percent

        var title: String {
            switch self {
            case .amount:
                return "金额"
            case .circle:
                return "圆环"
            case .percent:
                return "百分比"
            }
        }

        var symbol: String {
            switch self {
            case .amount:
                return "banknote"
            case .circle:
                return "gauge"
            case .percent:
                return "percent"
            }
        }
    }

    var timeRange: TimeRange {
        switch self {
        case .dailyUsedAmount, .dailyRemainingAmount, .dailyUsedCircle, .dailyRemainingCircle, .dailyUsedPercent, .dailyRemainingPercent:
            return .daily
        case .weeklyUsedAmount, .weeklyRemainingAmount, .weeklyUsedCircle, .weeklyRemainingCircle, .weeklyUsedPercent, .weeklyRemainingPercent:
            return .weekly
        }
    }

    var metricKind: MetricKind {
        switch self {
        case .dailyUsedAmount, .dailyUsedCircle, .dailyUsedPercent, .weeklyUsedAmount, .weeklyUsedCircle, .weeklyUsedPercent:
            return .used
        case .dailyRemainingAmount, .dailyRemainingCircle, .dailyRemainingPercent, .weeklyRemainingAmount, .weeklyRemainingCircle, .weeklyRemainingPercent:
            return .remaining
        }
    }

    var presentationKind: PresentationKind {
        switch self {
        case .dailyUsedAmount, .dailyRemainingAmount, .weeklyUsedAmount, .weeklyRemainingAmount:
            return .amount
        case .dailyUsedCircle, .dailyRemainingCircle, .weeklyUsedCircle, .weeklyRemainingCircle:
            return .circle
        case .dailyUsedPercent, .dailyRemainingPercent, .weeklyUsedPercent, .weeklyRemainingPercent:
            return .percent
        }
    }

    static func resolve(
        timeRange: TimeRange,
        metricKind: MetricKind,
        presentationKind: PresentationKind
    ) -> StatusDisplayStyle {
        switch (timeRange, metricKind, presentationKind) {
        case (.daily, .used, .amount):
            return .dailyUsedAmount
        case (.daily, .remaining, .amount):
            return .dailyRemainingAmount
        case (.daily, .used, .circle):
            return .dailyUsedCircle
        case (.daily, .remaining, .circle):
            return .dailyRemainingCircle
        case (.daily, .used, .percent):
            return .dailyUsedPercent
        case (.daily, .remaining, .percent):
            return .dailyRemainingPercent
        case (.weekly, .used, .amount):
            return .weeklyUsedAmount
        case (.weekly, .remaining, .amount):
            return .weeklyRemainingAmount
        case (.weekly, .used, .circle):
            return .weeklyUsedCircle
        case (.weekly, .remaining, .circle):
            return .weeklyRemainingCircle
        case (.weekly, .used, .percent):
            return .weeklyUsedPercent
        case (.weekly, .remaining, .percent):
            return .weeklyRemainingPercent
        }
    }

    var title: String {
        switch self {
        case .dailyUsedAmount:
            return "样式1: 日用：xx.xx"
        case .dailyRemainingAmount:
            return "样式2: 日余：xx.xx"
        case .dailyUsedCircle:
            return "样式3: 日用圆环"
        case .dailyRemainingCircle:
            return "样式4: 日余圆环"
        case .dailyUsedPercent:
            return "样式5: 日用：xx.xx%"
        case .dailyRemainingPercent:
            return "样式6: 日余：xx.xx%"
        case .weeklyUsedAmount:
            return "样式7: 周用：xx.xx"
        case .weeklyRemainingAmount:
            return "样式8: 周余：xx.xx"
        case .weeklyUsedCircle:
            return "样式9: 周用圆环"
        case .weeklyRemainingCircle:
            return "样式10: 周余圆环"
        case .weeklyUsedPercent:
            return "样式11: 周用：xx.xx%"
        case .weeklyRemainingPercent:
            return "样式12: 周余：xx.xx%"
        }
    }

    var chipTitle: String {
        switch self {
        case .dailyUsedAmount:
            return "每日用量(金额)"
        case .dailyRemainingAmount:
            return "每日剩余(金额)"
        case .dailyUsedCircle:
            return "每日用量(圆环)"
        case .dailyRemainingCircle:
            return "每日剩余(圆环)"
        case .dailyUsedPercent:
            return "每日用量(%)"
        case .dailyRemainingPercent:
            return "每日剩余(%)"
        case .weeklyUsedAmount:
            return "每周用量(金额)"
        case .weeklyRemainingAmount:
            return "每周剩余(金额)"
        case .weeklyUsedCircle:
            return "每周用量(圆环)"
        case .weeklyRemainingCircle:
            return "每周剩余(圆环)"
        case .weeklyUsedPercent:
            return "每周用量(%)"
        case .weeklyRemainingPercent:
            return "每周剩余(%)"
        }
    }

}

enum MenuPanelMode {
    case statistics
    case settings

    var toggleSymbol: String {
        switch self {
        case .statistics:
            return "gearshape"
        case .settings:
            return "chart.bar.xaxis"
        }
    }

    var toggleHint: String {
        switch self {
        case .statistics:
            return "打开设置"
        case .settings:
            return "返回统计信息"
        }
    }
}

enum StatusBarForegroundMode {
    case autoAdapt
    case manual
}

enum StatisticsDisplayMode: Int, CaseIterable {
    case single = 0
    case dual

    var title: String {
        switch self {
        case .single:
            return "单显"
        case .dual:
            return "双显"
        }
    }

    var fullTitle: String {
        switch self {
        case .single:
            return "单显模式"
        case .dual:
            return "双显模式"
        }
    }
}

struct APIEnvelope: Decodable {
    let code: Int?
    let msg: String?
    let state: APIState?
    let error: String?
    let details: String?
}

struct APIState: Decodable {
    let user: APIUser?
    let package: PackagePayload?
    let userPackgeUsageWeek: UsagePayload?
    let userPackgeUsage: UsagePayload?
    let remainingQuota: FlexibleNumber?

    enum CodingKeys: String, CodingKey {
        case user
        case package
        case userPackgeUsageWeek = "userPackgeUsage_week"
        case userPackgeUsage
        case remainingQuota = "remaining_quota"
    }
}

struct APIUser: Decodable {
    let email: String?
}

struct UsagePayload: Decodable {
    let remainingQuota: FlexibleNumber?
    let usedPercentage: FlexibleNumber?
    let totalCost: FlexibleNumber?
    let totalQuota: FlexibleNumber?
    let requestCount: FlexibleNumber?
    let inputTokens: FlexibleNumber?
    let inputTokensCached: FlexibleNumber?
    let outputTokens: FlexibleNumber?
    let outputTokensReasoning: FlexibleNumber?
    let totalTokens: FlexibleNumber?
    let inputCost: FlexibleNumber?
    let outputCost: FlexibleNumber?
    let cacheReadCost: FlexibleNumber?

    enum CodingKeys: String, CodingKey {
        case remainingQuota = "remaining_quota"
        case remainingQuotaCamel = "remainingQuota"
        case usedPercentage = "used_percentage"
        case usedPercentageCamel = "usedPercentage"
        case totalCost = "total_cost"
        case totalCostCamel = "totalCost"
        case totalQuota = "total_quota"
        case totalQuotaCamel = "totalQuota"
        case requestCount = "request_count"
        case requestCountCamel = "requestCount"
        case inputTokens = "input_tokens"
        case inputTokensCamel = "inputTokens"
        case inputTokensCached = "input_tokens_cached"
        case inputTokensCachedCamel = "inputTokensCached"
        case outputTokens = "output_tokens"
        case outputTokensCamel = "outputTokens"
        case outputTokensReasoning = "output_tokens_reasoning"
        case outputTokensReasoningCamel = "outputTokensReasoning"
        case totalTokens = "total_tokens"
        case totalTokensCamel = "totalTokens"
        case inputCost = "input_cost"
        case inputCostCamel = "inputCost"
        case outputCost = "output_cost"
        case outputCostCamel = "outputCost"
        case cacheReadCost = "cache_read_cost"
        case cacheReadCostCamel = "cacheReadCost"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remainingQuota = try container.decodeIfPresent(FlexibleNumber.self, forKey: .remainingQuota)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .remainingQuotaCamel)
        usedPercentage = try container.decodeIfPresent(FlexibleNumber.self, forKey: .usedPercentage)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .usedPercentageCamel)
        totalCost = try container.decodeIfPresent(FlexibleNumber.self, forKey: .totalCost)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .totalCostCamel)
        totalQuota = try container.decodeIfPresent(FlexibleNumber.self, forKey: .totalQuota)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .totalQuotaCamel)
        requestCount = try container.decodeIfPresent(FlexibleNumber.self, forKey: .requestCount)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .requestCountCamel)
        inputTokens = try container.decodeIfPresent(FlexibleNumber.self, forKey: .inputTokens)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .inputTokensCamel)
        inputTokensCached = try container.decodeIfPresent(FlexibleNumber.self, forKey: .inputTokensCached)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .inputTokensCachedCamel)
        outputTokens = try container.decodeIfPresent(FlexibleNumber.self, forKey: .outputTokens)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .outputTokensCamel)
        outputTokensReasoning = try container.decodeIfPresent(FlexibleNumber.self, forKey: .outputTokensReasoning)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .outputTokensReasoningCamel)
        totalTokens = try container.decodeIfPresent(FlexibleNumber.self, forKey: .totalTokens)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .totalTokensCamel)
        inputCost = try container.decodeIfPresent(FlexibleNumber.self, forKey: .inputCost)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .inputCostCamel)
        outputCost = try container.decodeIfPresent(FlexibleNumber.self, forKey: .outputCost)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .outputCostCamel)
        cacheReadCost = try container.decodeIfPresent(FlexibleNumber.self, forKey: .cacheReadCost)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .cacheReadCostCamel)
    }
}

struct PackagePayload: Decodable {
    let totalQuota: FlexibleNumber?
    let weeklyQuota: FlexibleNumber?
    let packages: [PackageItem]?

    enum CodingKeys: String, CodingKey {
        case totalQuota = "total_quota"
        case weeklyQuota
        case packages
    }
}

struct PackageItem: Decodable {
    let subType: String?
    let packageType: String?
    let packageStatus: String?
    let startAt: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case subType = "sub_type"
        case packageType = "package_type"
        case packageStatus = "package_status"
        case startAt = "start_at"
        case expiresAt = "expires_at"
    }
}

struct AGIPackageEnvelope: Decodable {
    let code: Int?
    let message: String?
    let data: AGIPackageData?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case msg
        case data
        case row
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(Int.self, forKey: .code)
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .msg)

        if let decodedData = try container.decodeIfPresent(AGIPackageData.self, forKey: .data) {
            data = decodedData
        } else if let row = try container.decodeIfPresent([AGIPackageItem].self, forKey: .row) {
            data = AGIPackageData(packages: row, summary: nil)
        } else {
            data = nil
        }
    }
}

struct AGIPackageData: Decodable {
    let packages: [AGIPackageItem]?
    let summary: AGIPackageSummary?
}

struct AGIPackageItem: Decodable {
    let pkgID: String?
    let orderClass: String?
    let level: Int?
    let byteTotal: FlexibleNumber?
    let byteRemaining: FlexibleNumber?
    let byteUsed: FlexibleNumber?
    let day: Int?
    let expireTime: String?
    let createTime: String?
    let reason: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case pkgID = "pkg_id"
        case orderClass = "order_class"
        case level
        case byte
        case byteTotal = "byte_total"
        case byteRemaining = "byte_remaining"
        case byteUsed = "byte_used"
        case day
        case expireTime
        case createTime
        case reason
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pkgID = try container.decodeIfPresent(String.self, forKey: .pkgID)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        orderClass = try container.decodeIfPresent(String.self, forKey: .orderClass)
        level = try container.decodeIfPresent(Int.self, forKey: .level)
        byteTotal = try container.decodeIfPresent(FlexibleNumber.self, forKey: .byteTotal)
        byteRemaining = try container.decodeIfPresent(FlexibleNumber.self, forKey: .byteRemaining)
            ?? container.decodeIfPresent(FlexibleNumber.self, forKey: .byte)

        if let explicitUsed = try container.decodeIfPresent(FlexibleNumber.self, forKey: .byteUsed) {
            byteUsed = explicitUsed
        } else if let total = byteTotal?.doubleValue, let remaining = byteRemaining?.doubleValue {
            byteUsed = .double(max(0, total - remaining))
        } else {
            byteUsed = nil
        }

        day = try container.decodeIfPresent(Int.self, forKey: .day)
        expireTime = try container.decodeIfPresent(String.self, forKey: .expireTime)
        createTime = try container.decodeIfPresent(String.self, forKey: .createTime)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        type = try container.decodeIfPresent(String.self, forKey: .type)
    }
}

struct AGIPackageSummary: Decodable {
    let pkgID: String?
    let totalPackages: Int?
    let totalByte: FlexibleNumber?
    let remainingByte: FlexibleNumber?
    let usedByte: FlexibleNumber?
    let highestLevel: Int?
    let userType: String?
    let latestExpireTime: String?

    enum CodingKeys: String, CodingKey {
        case pkgID = "pkg_id"
        case totalPackages = "total_packages"
        case totalByte = "total_byte"
        case remainingByte = "remaining_byte"
        case usedByte = "used_byte"
        case highestLevel = "highest_level"
        case userType = "user_type"
        case latestExpireTime = "latest_expire_time"
    }
}

enum FlexibleNumber: Decodable {
    case int(Int)
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        throw DecodingError.typeMismatch(
            FlexibleNumber.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported number format"
            )
        )
    }

    var display: String {
        switch self {
        case .int(let value):
            return "\(value)"
        case .double(let value):
            if value.rounded() == value {
                return "\(Int(value))"
            }
            return String(format: "%.2f", value)
        case .string(let value):
            return value
        }
    }

    var doubleValue: Double? {
        switch self {
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        case .string(let value):
            return Double(value.replacingOccurrences(of: "%", with: ""))
        }
    }
}

enum SummaryStatusTone: Equatable {
    case neutral
    case success
    case warning
    case critical

    var textColor: NSColor {
        switch self {
        case .neutral:
            return .secondaryLabelColor
        case .success:
            return .systemGreen
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }

    var fillColor: NSColor {
        textColor.withAlphaComponent(0.12)
    }

    var borderColor: NSColor {
        textColor.withAlphaComponent(0.22)
    }
}

struct StatusSummaryViewModel {
    let currentSource: PackageSource
    let currentSourceTitle: String
    let statisticsDisplayMode: StatisticsDisplayMode
    let emailText: String
    let canToggleEmail: Bool
    let isEmailVisible: Bool
    let usageValue: String
    let renewalValue: String
    let packageItems: [SummaryPackageItem]
    let progressLabel: String
    let progressPrefix: String?
    let progressValue: String
    let progress: Double?
    let footerText: String
    let codexAPIKeyStatusText: String
    let agiAPIKeyStatusText: String
    let codexAPIKeyMaskedText: String
    let agiAPIKeyMaskedText: String
    let pollIntervalSeconds: Double
    let launchAtLoginEnabled: Bool
    let launchAtLoginSupported: Bool
    let launchAtLoginUnavailableReason: String?
    let displayStyle: StatusDisplayStyle
    let statusBarForegroundMode: StatusBarForegroundMode
    let statusBarManualColorHex: String
    let statusBarColorText: String
    let panelMode: MenuPanelMode
    let mcpEnabled: Bool
    let mcpPort: UInt16
    let sourceGroups: [SourceSummaryGroupViewModel]
    let codexDashboard: CodexDashboardMetrics
    let codexUsageRecords: CodexUsageRecordsPanelViewModel
}

struct CodexDashboardMetrics {
    let dailyUsedQuota: Double?
    let dailyTotalQuota: Double?
    let dailyUsedPercent: Double?
    let weeklyUsedQuota: Double?
    let weeklyTotalQuota: Double?
    let weeklyUsedPercent: Double?
    let requestCount: Int?
    let totalCost: Double?
    let totalTokens: Double?
    let inputTokens: Double?
    let cachedInputTokens: Double?
    let outputTokens: Double?

    static let empty = CodexDashboardMetrics(
        dailyUsedQuota: nil,
        dailyTotalQuota: nil,
        dailyUsedPercent: nil,
        weeklyUsedQuota: nil,
        weeklyTotalQuota: nil,
        weeklyUsedPercent: nil,
        requestCount: nil,
        totalCost: nil,
        totalTokens: nil,
        inputTokens: nil,
        cachedInputTokens: nil,
        outputTokens: nil
    )
}

struct CodexUsageRecordViewModel {
    let id: String
    let timestampText: String
    let modelText: String
    let tierText: String
    let totalTokensText: String
    let tokenBreakdownText: String
    let totalCostText: String
    let costBreakdownText: String
    let detailURL: String?
    let totalTokensValue: Double?
    let totalCostValue: Double?

    init(
        id: String,
        timestampText: String,
        modelText: String,
        tierText: String,
        totalTokensText: String,
        tokenBreakdownText: String,
        totalCostText: String,
        costBreakdownText: String,
        detailURL: String?,
        totalTokensValue: Double? = nil,
        totalCostValue: Double? = nil
    ) {
        self.id = id
        self.timestampText = timestampText
        self.modelText = modelText
        self.tierText = tierText
        self.totalTokensText = totalTokensText
        self.tokenBreakdownText = tokenBreakdownText
        self.totalCostText = totalCostText
        self.costBreakdownText = costBreakdownText
        self.detailURL = detailURL
        self.totalTokensValue = totalTokensValue
        self.totalCostValue = totalCostValue
    }
}

struct CodexUsageRecordsPanelViewModel {
    let records: [CodexUsageRecordViewModel]
    let page: Int
    let pageSize: Int
    let totalCount: Int?
    let totalPages: Int?
    let totalCostText: String?
    let pageCostText: String?
    let totalTokensText: String?
    let pageTokensText: String?
    let errorText: String?
}

extension CodexUsageRecordsPanelViewModel {
    static let empty = CodexUsageRecordsPanelViewModel(
        records: [],
        page: 1,
        pageSize: 20,
        totalCount: nil,
        totalPages: nil,
        totalCostText: nil,
        pageCostText: nil,
        totalTokensText: nil,
        pageTokensText: nil,
        errorText: nil
    )

    static func error(_ text: String, page: Int = 1, pageSize: Int = 20) -> CodexUsageRecordsPanelViewModel {
        CodexUsageRecordsPanelViewModel(
            records: [],
            page: page,
            pageSize: pageSize,
            totalCount: nil,
            totalPages: nil,
            totalCostText: nil,
            pageCostText: nil,
            totalTokensText: nil,
            pageTokensText: nil,
            errorText: text
        )
    }

    var summaryText: String {
        var parts: [String] = []
        if let totalCount {
            parts.append("\(totalCount) 条")
        }
        if let totalCostText, !totalCostText.isEmpty {
            parts.append("累计 \(totalCostText)")
        }
        if let pageCostText, !pageCostText.isEmpty {
            parts.append("本页 \(pageCostText)")
        }
        if let pageTokensText, !pageTokensText.isEmpty {
            parts.append("本页 \(pageTokensText) tokens")
        }
        return parts.joined(separator: " · ")
    }
}

struct SourceSummaryGroupViewModel {
    let source: PackageSource
    let statusText: String
    let statusTone: SummaryStatusTone
    let usageLabel: String
    let usageValue: String
    let remainingValue: String
    let renewalLabel: String
    let renewalValue: String
    let packageItems: [SummaryPackageItem]
    let progressLabel: String
    let progressPrefix: String?
    let progressValue: String
    let progress: Double?
    let footerText: String
    let isExpanded: Bool
}

struct SourceMonitorState {
    let source: PackageSource
    var usage: String
    var remaining: String
    var renewal: String
    var message: String
    var usageLabel: String
    var progressLabel: String
    var progressPrefix: String?
    var email: String?
    var packageItems: [SummaryPackageItem]
    var usedPercent: Double?
    var fallbackText: String
    var dailyRemaining: String?
    var dailyUsagePayload: UsagePayload?
    var weeklyUsagePayload: UsagePayload?

    static func placeholder(for source: PackageSource, hasAPIKey: Bool) -> SourceMonitorState {
        SourceMonitorState(
            source: source,
            usage: "--",
            remaining: "--",
            renewal: "--",
            message: hasAPIKey ? "等待数据" : "请先设置\(source.settingsTitle) API Key",
            usageLabel: source == .agi ? "已用字节/总字节" : "已用/总",
            progressLabel: source == .agi ? "AGI 用量进度" : "用量进度",
            progressPrefix: nil,
            email: nil,
            packageItems: [],
            usedPercent: nil,
            fallbackText: hasAPIKey ? "\(source.chipTitle): 加载中..." : "\(source.chipTitle): 未配置Key",
            dailyRemaining: nil,
            dailyUsagePayload: nil,
            weeklyUsagePayload: nil
        )
    }
}

struct SummaryPackageItem {
    let title: String
    let subtitle: String
    let badgeText: String
    let badgeTone: SummaryStatusTone
}

extension SummaryStatusTone {
    var swiftUIColor: Color { Color(nsColor: textColor) }
    var swiftUIFillColor: Color { Color(nsColor: fillColor) }
    var swiftUIBorderColor: Color { Color(nsColor: borderColor) }
}

extension StatusSummaryViewModel {
    static let placeholder = StatusSummaryViewModel(
        currentSource: .codex,
        currentSourceTitle: PackageSource.codex.chipTitle,
        statisticsDisplayMode: .single,
        emailText: "--",
        canToggleEmail: false,
        isEmailVisible: false,
        usageValue: "--",
        renewalValue: "--",
        packageItems: [],
        progressLabel: "本周用量进度",
        progressPrefix: nil,
        progressValue: "--",
        progress: nil,
        footerText: "等待数据",
        codexAPIKeyStatusText: "未配置",
        agiAPIKeyStatusText: "未配置",
        codexAPIKeyMaskedText: "",
        agiAPIKeyMaskedText: "",
        pollIntervalSeconds: 5,
        launchAtLoginEnabled: true,
        launchAtLoginSupported: true,
        launchAtLoginUnavailableReason: nil,
        displayStyle: .dailyRemainingAmount,
        statusBarForegroundMode: .autoAdapt,
        statusBarManualColorHex: AppMeta.defaultStatusBarColorHex,
        statusBarColorText: "自动适配（手动 #FFFFFF）",
        panelMode: .statistics,
        mcpEnabled: false,
        mcpPort: AppMeta.defaultMCPPort,
        sourceGroups: [],
        codexDashboard: .empty,
        codexUsageRecords: .empty
    )
}
