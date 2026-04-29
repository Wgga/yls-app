import CoreGraphics
import Foundation

public enum DefaultsKey {
    public static let apiKey = "api_key"
    public static let codexAPIKey = "codex_api_key"
    public static let agiAPIKey = "agi_api_key"
    public static let selectedSource = "selected_source"
    public static let statisticsDisplayMode = "statistics_display_mode"
    public static let interval = "poll_interval_seconds"
    public static let displayStyle = "status_display_style"
    public static let statusBarColorAutoAdapt = "status_bar_color_auto_adapt"
    public static let statusBarColorHex = "status_bar_color_hex"
    public static let mcpEnabled = "mcp_enabled"
    public static let mcpPort = "mcp_port"
    public static let launchAtLoginEnabled = "launch_at_login_enabled"
}

public enum AppMeta {
    public static let displayName = "伊莉思监控助手"
    public static let codexEndpoint = URL(string: "https://code.ylsagi.com/codex/info")!
    public static let codexLogsEndpoint = URL(string: "https://code.ylsagi.com/codex/logs")!
    public static let agiPackageEndpoint = URL(string: "https://api.ylsagi.com/user/package")!
    public static let agiEnvironmentKey = "YLS_AGI_KEY"
    public static let dashboardURL = "https://code.ylsagi.com/user/dashboard"
    public static let pricingURL = "https://code.ylsagi.com/pricing"
    public static let mcpHost = "127.0.0.1"
    public static let defaultMCPPort: UInt16 = 8765
    public static let stackedStatusMinWidth: CGFloat = 44
    public static let stackedStatusMaxWidth: CGFloat = 72
    public static let stackedHorizontalPadding: CGFloat = 4
    public static let stackedStatusHeight: CGFloat = 18
    public static let stackedLineGap: CGFloat = 1
    public static let stackedVerticalNudge: CGFloat = -0.5
    public static let stackedTopFontSize: CGFloat = 9.5
    public static let stackedBottomFontSize: CGFloat = 7.5
    public static let circleMinWidth: CGFloat = 44
    public static let circleMaxWidth: CGFloat = 76
    public static let circleHorizontalPadding: CGFloat = 4
    public static let circleBottomFontSize: CGFloat = 8
    public static let circleLineGap: CGFloat = 1
    public static let circleLineWidth: CGFloat = 1.8
    public static let circleDiameter: CGFloat = 13
    public static let defaultStatusBarColorHex = "#FFFFFF"
}

public enum PackageSource: String, CaseIterable, Sendable {
    case codex
    case agi

    public var title: String {
        switch self {
        case .codex:
            return "Codex 套餐"
        case .agi:
            return "AGI 套餐"
        }
    }

    public var chipTitle: String {
        switch self {
        case .codex:
            return "Codex"
        case .agi:
            return "AGI"
        }
    }

    public var settingsTitle: String {
        switch self {
        case .codex:
            return "Codex"
        case .agi:
            return "AGI"
        }
    }

    public var keyButtonTitle: String {
        switch self {
        case .codex:
            return "Codex API Key"
        case .agi:
            return "AGI API Key"
        }
    }

    public var dashboardURL: String? {
        switch self {
        case .codex:
            return AppMeta.dashboardURL
        case .agi:
            return nil
        }
    }

    public var pricingURL: String? {
        switch self {
        case .codex:
            return AppMeta.pricingURL
        case .agi:
            return nil
        }
    }

    public var openDashboardTitle: String {
        switch self {
        case .codex:
            return "打开 Codex 控制台"
        case .agi:
            return "打开套餐控制台"
        }
    }
}

public enum StatusDisplayStyle: Int, CaseIterable, Sendable {
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

    public static let selectorOrder: [StatusDisplayStyle] = [
        .dailyUsedAmount,
        .dailyRemainingAmount,
        .dailyUsedCircle,
        .dailyRemainingCircle,
        .dailyUsedPercent,
        .dailyRemainingPercent,
        .weeklyUsedAmount,
        .weeklyRemainingAmount,
        .weeklyUsedCircle,
        .weeklyRemainingCircle,
        .weeklyUsedPercent,
        .weeklyRemainingPercent
    ]

    public enum TimeRange: String, CaseIterable, Sendable {
        case daily
        case weekly

        public var title: String {
            switch self {
            case .daily:
                return "每日"
            case .weekly:
                return "每周"
            }
        }

        public var symbol: String {
            switch self {
            case .daily:
                return "sun.max"
            case .weekly:
                return "calendar"
            }
        }
    }

    public enum MetricKind: String, CaseIterable, Sendable {
        case used
        case remaining

        public var title: String {
            switch self {
            case .used:
                return "用量"
            case .remaining:
                return "剩余"
            }
        }

        public var symbol: String {
            switch self {
            case .used:
                return "arrow.up.forward"
            case .remaining:
                return "arrow.down.forward"
            }
        }
    }

    public enum PresentationKind: String, CaseIterable, Sendable {
        case amount
        case circle
        case percent

        public var title: String {
            switch self {
            case .amount:
                return "金额"
            case .circle:
                return "圆环"
            case .percent:
                return "百分比"
            }
        }

        public var symbol: String {
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

    public var timeRange: TimeRange {
        switch self {
        case .dailyUsedAmount, .dailyRemainingAmount, .dailyUsedCircle, .dailyRemainingCircle, .dailyUsedPercent, .dailyRemainingPercent:
            return .daily
        case .weeklyUsedAmount, .weeklyRemainingAmount, .weeklyUsedCircle, .weeklyRemainingCircle, .weeklyUsedPercent, .weeklyRemainingPercent:
            return .weekly
        }
    }

    public var metricKind: MetricKind {
        switch self {
        case .dailyUsedAmount, .dailyUsedCircle, .dailyUsedPercent, .weeklyUsedAmount, .weeklyUsedCircle, .weeklyUsedPercent:
            return .used
        case .dailyRemainingAmount, .dailyRemainingCircle, .dailyRemainingPercent, .weeklyRemainingAmount, .weeklyRemainingCircle, .weeklyRemainingPercent:
            return .remaining
        }
    }

    public var presentationKind: PresentationKind {
        switch self {
        case .dailyUsedAmount, .dailyRemainingAmount, .weeklyUsedAmount, .weeklyRemainingAmount:
            return .amount
        case .dailyUsedCircle, .dailyRemainingCircle, .weeklyUsedCircle, .weeklyRemainingCircle:
            return .circle
        case .dailyUsedPercent, .dailyRemainingPercent, .weeklyUsedPercent, .weeklyRemainingPercent:
            return .percent
        }
    }

    public static func resolve(
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

    public var title: String {
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

    public var chipTitle: String {
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

    public var selectorSymbol: String {
        switch self {
        case .dailyUsedAmount:
            return "banknote"
        case .dailyRemainingAmount:
            return "text.alignleft"
        case .dailyUsedCircle:
            return "gauge.with.dots.needle.bottom.50percent"
        case .dailyRemainingCircle:
            return "gauge"
        case .dailyUsedPercent:
            return "chart.bar.fill"
        case .dailyRemainingPercent:
            return "chart.bar.doc.horizontal"
        case .weeklyUsedAmount:
            return "banknote.fill"
        case .weeklyRemainingAmount:
            return "text.alignright"
        case .weeklyUsedCircle:
            return "smallcircle.filled.circle"
        case .weeklyRemainingCircle:
            return "smallcircle.circle"
        case .weeklyUsedPercent:
            return "chart.bar.xaxis"
        case .weeklyRemainingPercent:
            return "chart.xyaxis.line"
        }
    }

    public var selectorPreview: String {
        switch self {
        case .dailyUsedAmount:
            return "日用：9.53"
        case .dailyRemainingAmount:
            return "日余：90.47"
        case .dailyUsedCircle:
            return "圆环 + 日用"
        case .dailyRemainingCircle:
            return "圆环 + 日余"
        case .dailyUsedPercent:
            return "日用：9.53%"
        case .dailyRemainingPercent:
            return "日余：90.47%"
        case .weeklyUsedAmount:
            return "周用：14.06"
        case .weeklyRemainingAmount:
            return "周余：85.94"
        case .weeklyUsedCircle:
            return "圆环 + 周用"
        case .weeklyRemainingCircle:
            return "圆环 + 周余"
        case .weeklyUsedPercent:
            return "周用：14.06%"
        case .weeklyRemainingPercent:
            return "周余：85.94%"
        }
    }
}

public enum MenuPanelMode: Sendable {
    case statistics
    case settings

    public var toggleSymbol: String {
        switch self {
        case .statistics:
            return "gearshape"
        case .settings:
            return "chart.bar.xaxis"
        }
    }

    public var toggleHint: String {
        switch self {
        case .statistics:
            return "打开设置"
        case .settings:
            return "返回统计信息"
        }
    }
}

public enum StatusBarForegroundMode: Sendable {
    case autoAdapt
    case manual
}

public enum StatisticsDisplayMode: Int, CaseIterable, Sendable {
    case single = 0
    case dual

    public var title: String {
        switch self {
        case .single:
            return "单显"
        case .dual:
            return "双显"
        }
    }

    public var fullTitle: String {
        switch self {
        case .single:
            return "单显模式"
        case .dual:
            return "双显模式"
        }
    }
}

public enum StatisticsGroupKind: String, CaseIterable, Hashable, Sendable {
    case codex
    case agi
}

public struct StatisticsGroupAccessory: Sendable {
    public let text: String
    public let tone: SummaryStatusTone?

    static func label(_ text: String) -> StatisticsGroupAccessory {
        StatisticsGroupAccessory(text: text, tone: nil)
    }

    static func status(_ text: String, tone: SummaryStatusTone) -> StatisticsGroupAccessory {
        StatisticsGroupAccessory(text: text, tone: tone)
    }
}

public struct APIEnvelope: Decodable, Sendable {
    public let code: Int?
    public let msg: String?
    public let state: APIState?
    public let error: String?
    public let details: String?
}

public struct APIState: Decodable, Sendable {
    public let user: APIUser?
    public let package: PackagePayload?
    public let userPackgeUsageWeek: UsagePayload?
    public let userPackgeUsage: UsagePayload?
    public let remainingQuota: FlexibleNumber?

    public enum CodingKeys: String, CodingKey, Sendable {
        case user
        case package
        case userPackgeUsageWeek = "userPackgeUsage_week"
        case userPackgeUsage
        case remainingQuota = "remaining_quota"
    }
}

public struct APIUser: Decodable, Sendable {
    public let email: String?
}

public struct UsagePayload: Decodable, Sendable {
    public let remainingQuota: FlexibleNumber?
    public let usedPercentage: FlexibleNumber?
    public let totalCost: FlexibleNumber?
    public let totalQuota: FlexibleNumber?
    public let requestCount: FlexibleNumber?
    public let inputTokens: FlexibleNumber?
    public let inputTokensCached: FlexibleNumber?
    public let outputTokens: FlexibleNumber?
    public let outputTokensReasoning: FlexibleNumber?
    public let totalTokens: FlexibleNumber?
    public let inputCost: FlexibleNumber?
    public let outputCost: FlexibleNumber?
    public let cacheReadCost: FlexibleNumber?

    public enum CodingKeys: String, CodingKey, Sendable {
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

    public init(from decoder: Decoder) throws {
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

public struct PackagePayload: Decodable, Sendable {
    public let totalQuota: FlexibleNumber?
    public let weeklyQuota: FlexibleNumber?
    public let packages: [PackageItem]?

    public enum CodingKeys: String, CodingKey, Sendable {
        case totalQuota = "total_quota"
        case weeklyQuota
        case packages
    }
}

public struct PackageItem: Decodable, Sendable {
    public let packageType: String?
    public let packageStatus: String?
    public let startAt: String?
    public let expiresAt: String?

    public enum CodingKeys: String, CodingKey, Sendable {
        case packageType = "package_type"
        case packageStatus = "package_status"
        case startAt = "start_at"
        case expiresAt = "expires_at"
    }
}

public struct AGIPackageEnvelope: Decodable, Sendable {
    public let code: Int?
    public let message: String?
    public let data: AGIPackageData?
}

public struct AGIPackageData: Decodable, Sendable {
    public let packages: [AGIPackageItem]?
    public let summary: AGIPackageSummary?
}

public struct AGIPackageItem: Decodable, Sendable {
    public let pkgID: String?
    public let orderClass: String?
    public let level: Int?
    public let byteTotal: FlexibleNumber?
    public let byteRemaining: FlexibleNumber?
    public let byteUsed: FlexibleNumber?
    public let day: Int?
    public let expireTime: String?
    public let createTime: String?
    public let reason: String?
    public let type: String?

    public enum CodingKeys: String, CodingKey, Sendable {
        case pkgID = "pkg_id"
        case orderClass = "order_class"
        case level
        case byteTotal = "byte_total"
        case byteRemaining = "byte_remaining"
        case byteUsed = "byte_used"
        case day
        case expireTime
        case createTime
        case reason
        case type
    }
}

public struct AGIPackageSummary: Decodable, Sendable {
    public let pkgID: String?
    public let totalPackages: Int?
    public let totalByte: FlexibleNumber?
    public let remainingByte: FlexibleNumber?
    public let usedByte: FlexibleNumber?
    public let highestLevel: Int?
    public let userType: String?
    public let latestExpireTime: String?

    public enum CodingKeys: String, CodingKey, Sendable {
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

public enum FlexibleNumber: Decodable, Sendable {
    case int(Int)
    case double(Double)
    case string(String)

    public init(from decoder: Decoder) throws {
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

    public var display: String {
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

    public var doubleValue: Double? {
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

public enum SummaryStatusTone: Equatable, Sendable {
    case neutral
    case success
    case warning
    case critical
}

public struct StatusSummaryViewModel: Sendable {
    public let title: String
    public let currentSource: PackageSource
    public let currentSourceTitle: String
    public let statisticsDisplayMode: StatisticsDisplayMode
    public let statisticsModeText: String
    public let statusText: String
    public let statusTone: SummaryStatusTone
    public let emailText: String
    public let canToggleEmail: Bool
    public let isEmailVisible: Bool
    public let usageLabel: String
    public let usageValue: String
    public let remainingValue: String
    public let renewalLabel: String
    public let renewalValue: String
    public let packageSectionTitle: String?
    public let packageItems: [SummaryPackageItem]
    public let progressLabel: String
    public let progressPrefix: String?
    public let progressValue: String
    public let progress: Double?
    public let footerText: String
    public let hasAPIKey: Bool
    public let hasAGIKey: Bool
    public let codexAPIKeyStatusText: String
    public let agiAPIKeyStatusText: String
    public let codexAPIKeyMaskedText: String
    public let agiAPIKeyMaskedText: String
    public let pollIntervalSeconds: Double
    public let pollIntervalText: String
    public let launchAtLoginEnabled: Bool
    public let launchAtLoginSupported: Bool
    public let launchAtLoginUnavailableReason: String?
    public let displayStyle: StatusDisplayStyle
    public let statusBarForegroundMode: StatusBarForegroundMode
    public let statusBarManualColorHex: String
    public let statusBarColorText: String
    public let panelMode: MenuPanelMode
    public let mcpStatusText: String
    public let mcpEnabled: Bool
    public let mcpPort: UInt16
    public let canOpenDashboard: Bool
    public let canOpenPricing: Bool
    public let dashboardActionTitle: String
    public let sourceGroups: [SourceSummaryGroupViewModel]
    public let mountedModules: [MountedPackageModuleSummary]
    public let codexDashboard: CodexDashboardMetrics
    public let codexUsageRecords: CodexUsageRecordsPanelViewModel
}

public struct CodexDashboardMetrics: Sendable {
    public let dailyUsedQuota: Double?
    public let dailyTotalQuota: Double?
    public let dailyUsedPercent: Double?
    public let weeklyUsedQuota: Double?
    public let weeklyTotalQuota: Double?
    public let weeklyUsedPercent: Double?
    public let requestCount: Int?
    public let totalCost: Double?
    public let totalTokens: Double?
    public let inputTokens: Double?
    public let cachedInputTokens: Double?
    public let outputTokens: Double?

    public static let empty = CodexDashboardMetrics(
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

public struct CodexUsageRecordViewModel: Sendable {
    public let id: String
    public let timestampText: String
    public let modelText: String
    public let tierText: String
    public let totalTokensText: String
    public let tokenBreakdownText: String
    public let totalCostText: String
    public let costBreakdownText: String
    public let detailURL: String?
    public let totalTokensValue: Double?
    public let totalCostValue: Double?

    public init(
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

public struct CodexUsageRecordsPanelViewModel: Sendable {
    public let records: [CodexUsageRecordViewModel]
    public let page: Int
    public let pageSize: Int
    public let totalCount: Int?
    public let totalPages: Int?
    public let totalCostText: String?
    public let pageCostText: String?
    public let totalTokensText: String?
    public let pageTokensText: String?
    public let errorText: String?
}

extension CodexUsageRecordsPanelViewModel {
    public static let empty = CodexUsageRecordsPanelViewModel(
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

    public var summaryText: String {
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

public struct SourceSummaryGroupViewModel: Sendable {
    public let source: PackageSource
    public let statusText: String
    public let statusTone: SummaryStatusTone
    public let usageLabel: String
    public let usageValue: String
    public let remainingValue: String
    public let renewalLabel: String
    public let renewalValue: String
    public let packageItems: [SummaryPackageItem]
    public let progressLabel: String
    public let progressPrefix: String?
    public let progressValue: String
    public let progress: Double?
    public let footerText: String
    public let isExpanded: Bool
}

public struct NormalizedMonitorPayload: Sendable {
    public let usage: String
    public let remaining: String
    public let renewal: String?
    public let packageItems: [SummaryPackageItem]
    public let usedPercent: Double?
    public let usageLabel: String
    public let progressLabel: String
    public let progressPrefix: String?
    public let email: String?
}

public struct SourceMonitorState: Sendable {
    public let source: PackageSource
    public var usage: String
    public var remaining: String
    public var renewal: String
    public var message: String
    public var usageLabel: String
    public var progressLabel: String
    public var progressPrefix: String?
    public var email: String?
    public var packageItems: [SummaryPackageItem]
    public var usedPercent: Double?
    public var fallbackText: String
    public var dailyRemaining: String?
    public var dailyUsagePayload: UsagePayload?
    public var weeklyUsagePayload: UsagePayload?

    static func placeholder(for source: PackageSource, hasAPIKey: Bool) -> SourceMonitorState {
        SourceMonitorState(
            source: source,
            usage: "--",
            remaining: "--",
            renewal: "--",
            message: hasAPIKey ? "等待数据" : "请先设置\(source.settingsTitle) API Key",
            usageLabel: source == .agi ? "已用/总字节" : "已用/总",
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

public struct MountedPackageModuleSummary: Sendable {
    public let title: String
    public let statusText: String
    public let statusTone: SummaryStatusTone
    public let usageLabel: String
    public let usageValue: String
    public let remainingLabel: String
    public let remainingValue: String
    public let renewalLabel: String
    public let renewalValue: String
    public let progressLabel: String
    public let progressValue: String
    public let progress: Double?
    public let footerText: String
    public let packageSectionTitle: String?
    public let packageItems: [SummaryPackageItem]
}

public struct SummaryPackageItem: Sendable {
    public let title: String
    public let subtitle: String
    public let badgeText: String
    public let badgeTone: SummaryStatusTone
}

extension StatusSummaryViewModel {
    public static let placeholder = StatusSummaryViewModel(
        title: AppMeta.displayName,
        currentSource: .codex,
        currentSourceTitle: PackageSource.codex.chipTitle,
        statisticsDisplayMode: .single,
        statisticsModeText: StatisticsDisplayMode.single.fullTitle,
        statusText: "等待中",
        statusTone: .neutral,
        emailText: "--",
        canToggleEmail: false,
        isEmailVisible: false,
        usageLabel: "已用/总",
        usageValue: "--",
        remainingValue: "--",
        renewalLabel: "最近到期",
        renewalValue: "--",
        packageSectionTitle: nil,
        packageItems: [],
        progressLabel: "本周用量进度",
        progressPrefix: nil,
        progressValue: "--",
        progress: nil,
        footerText: "等待数据",
        hasAPIKey: false,
        hasAGIKey: false,
        codexAPIKeyStatusText: "未配置",
        agiAPIKeyStatusText: "未配置",
        codexAPIKeyMaskedText: "",
        agiAPIKeyMaskedText: "",
        pollIntervalSeconds: 5,
        pollIntervalText: "--",
        launchAtLoginEnabled: true,
        launchAtLoginSupported: true,
        launchAtLoginUnavailableReason: nil,
        displayStyle: .dailyRemainingAmount,
        statusBarForegroundMode: .autoAdapt,
        statusBarManualColorHex: AppMeta.defaultStatusBarColorHex,
        statusBarColorText: "自动适配（手动 #FFFFFF）",
        panelMode: .statistics,
        mcpStatusText: "MCP 未启动",
        mcpEnabled: false,
        mcpPort: AppMeta.defaultMCPPort,
        canOpenDashboard: true,
        canOpenPricing: true,
        dashboardActionTitle: PackageSource.codex.openDashboardTitle,
        sourceGroups: [],
        mountedModules: [],
        codexDashboard: .empty,
        codexUsageRecords: .empty
    )
}
