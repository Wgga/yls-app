import Foundation

@MainActor
protocol CodexMonitorNetworkServing {
    func fetchCodexUsageInfo(
        using request: CodexUsageInfoRequestViewModel
    ) async throws -> CodexUsageInfoResponseViewModel

    func fetchCodexUsageLogs(
        using request: CodexUsageLogsRequestViewModel
    ) async throws -> CodexUsageLogsResponseViewModel

    func fetchAGIPackageInfo(
        using request: AGIPackageInfoRequestViewModel
    ) async throws -> AGIPackageInfoResponseViewModel
}

enum CodexMonitorHTTPMethod: String {
    case get = "GET"
}

struct CodexUsageInfoRequestViewModel {
    let endpoint: URL
    let method: CodexMonitorHTTPMethod
    let bearerToken: String
    let timeoutInterval: TimeInterval
    let queryItems: [URLQueryItem]

    init(
        apiKey: String,
        endpoint: URL = AppMeta.codexEndpoint,
        timeoutInterval: TimeInterval = 20,
        queryItems: [URLQueryItem] = []
    ) {
        self.endpoint = endpoint
        self.method = .get
        self.bearerToken = apiKey
        self.timeoutInterval = timeoutInterval
        self.queryItems = queryItems
    }

    var headers: [String: String] {
        ["Authorization": "Bearer \(bearerToken)"]
    }

    func makeURLRequest() -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        var request = URLRequest(url: components?.url ?? endpoint)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

struct CodexUsageLogsRequestViewModel {
    let endpoint: URL
    let method: CodexMonitorHTTPMethod
    let bearerToken: String
    let timeoutInterval: TimeInterval
    let page: Int
    let pageSize: Int

    init(
        apiKey: String,
        page: Int,
        pageSize: Int,
        endpoint: URL = AppMeta.codexLogsEndpoint,
        timeoutInterval: TimeInterval = 20
    ) {
        self.endpoint = endpoint
        self.method = .get
        self.bearerToken = apiKey
        self.timeoutInterval = timeoutInterval
        self.page = max(1, page)
        self.pageSize = max(1, pageSize)
    }

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
        ]
    }

    var headers: [String: String] {
        ["Authorization": "Bearer \(bearerToken)"]
    }

    func makeURLRequest() -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems

        var request = URLRequest(url: components?.url ?? endpoint)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

struct AGIPackageInfoRequestViewModel {
    let endpoint: URL
    let method: CodexMonitorHTTPMethod
    let bearerToken: String
    let timeoutInterval: TimeInterval
    let queryItems: [URLQueryItem]

    init(
        apiKey: String,
        endpoint: URL = AppMeta.agiPackageEndpoint,
        timeoutInterval: TimeInterval = 20,
        queryItems: [URLQueryItem] = []
    ) {
        self.endpoint = endpoint
        self.method = .get
        self.bearerToken = apiKey
        self.timeoutInterval = timeoutInterval
        self.queryItems = queryItems
    }

    var headers: [String: String] {
        ["Authorization": "Bearer \(bearerToken)"]
    }

    func makeURLRequest() -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        var request = URLRequest(url: components?.url ?? endpoint)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

struct CodexUsageInfoResponseViewModel {
    struct Metadata {
        let httpStatusCode: Int
        let businessCode: Int?
        let message: String?
        let details: String?
    }

    struct StateViewModel {
        let email: String?
        let usageText: String
        let remainingText: String
        let dailyRemainingText: String
        let weeklyRemainingText: String
        let usedPercent: Double?
        let renewalText: String
        let packageItems: [SummaryPackageItem]
        let usageLabel: String
        let progressLabel: String
        let progressPrefix: String?
        let dailyUsagePayload: UsagePayload?
        let weeklyUsagePayload: UsagePayload?
    }

    let request: CodexUsageInfoRequestViewModel
    let metadata: Metadata
    let state: StateViewModel
}

struct CodexUsageLogsResponseViewModel {
    struct Metadata {
        let httpStatusCode: Int
        let businessCode: Int?
        let message: String?
        let details: String?
    }

    struct StateViewModel {
        let panel: CodexUsageRecordsPanelViewModel
    }

    let request: CodexUsageLogsRequestViewModel
    let metadata: Metadata
    let state: StateViewModel
}

struct AGIPackageInfoResponseViewModel {
    struct Metadata {
        let httpStatusCode: Int
        let businessCode: Int?
        let message: String?
    }

    struct StateViewModel {
        let usageText: String
        let remainingText: String
        let usedPercent: Double?
        let renewalText: String
        let packageItems: [SummaryPackageItem]
    }

    let request: AGIPackageInfoRequestViewModel
    let metadata: Metadata
    let state: StateViewModel
}

enum CodexMonitorNetworkError: Error {
    case invalidHTTPResponse(source: PackageSource)
    case httpStatus(source: PackageSource, statusCode: Int)
    case business(source: PackageSource, code: Int, message: String)
    case unauthorized(source: PackageSource, message: String)
    case missingField(source: PackageSource, field: String)
    case decoding(source: PackageSource, message: String, snippet: String?)
    case transport(source: PackageSource, message: String)
}

@MainActor
final class CodexMonitorNetworkService: CodexMonitorNetworkServing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCodexUsageInfo(
        using request: CodexUsageInfoRequestViewModel
    ) async throws -> CodexUsageInfoResponseViewModel {
        let urlRequest = request.makeURLRequest()
        let data: Data
        let httpResponse: HTTPURLResponse

        do {
            let (responseData, response) = try await session.data(for: urlRequest)
            guard let typedResponse = response as? HTTPURLResponse else {
                throw CodexMonitorNetworkError.invalidHTTPResponse(source: .codex)
            }
            data = responseData
            httpResponse = typedResponse
        } catch let error as CodexMonitorNetworkError {
            throw error
        } catch {
            throw CodexMonitorNetworkError.transport(source: .codex, message: error.localizedDescription)
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw CodexMonitorNetworkError.httpStatus(source: .codex, statusCode: httpResponse.statusCode)
        }

        let decoded: APIEnvelope
        do {
            decoded = try JSONDecoder().decode(APIEnvelope.self, from: data)
        } catch {
            throw CodexMonitorNetworkError.decoding(
                source: .codex,
                message: error.localizedDescription,
                snippet: Self.rawSnippet(from: data)
            )
        }

        if let code = decoded.code, !Self.successBusinessCodes.contains(code) {
            let apiMessage = decoded.msg ?? decoded.error ?? decoded.details ?? "接口返回业务错误"
            throw CodexMonitorNetworkError.business(source: .codex, code: code, message: apiMessage)
        }

        if let errorText = decoded.error {
            let details = decoded.details ?? decoded.msg ?? errorText
            throw CodexMonitorNetworkError.unauthorized(source: .codex, message: details)
        }

        guard let state = decoded.state else {
            throw CodexMonitorNetworkError.missingField(source: .codex, field: "state")
        }

        let packageUsagePayload = state.userPackgeUsage
        let weeklyUsagePayload = state.userPackgeUsageWeek
        let displayUsagePayload = weeklyUsagePayload ?? packageUsagePayload

        guard let remainingNumber = packageUsagePayload?.remainingQuota
            ?? state.remainingQuota
            ?? displayUsagePayload?.remainingQuota
        else {
            throw CodexMonitorNetworkError.missingField(source: .codex, field: "remaining_quota")
        }

        let packageRemaining = state.remainingQuota?.display ?? remainingNumber.display
        let dailyRemaining = packageUsagePayload?.remainingQuota?.display ?? "--"
        let weeklyRemaining = weeklyUsagePayload?.remainingQuota?.display ?? "--"

        let usageRemainingNumber = displayUsagePayload?.remainingQuota ?? remainingNumber
        let packageRemainingNumber = packageUsagePayload?.remainingQuota ?? remainingNumber

        let usedPercent = Self.resolveUsedPercentage(usage: displayUsagePayload, remaining: usageRemainingNumber)
        let usageQuotaPair = Self.resolveUsageQuotaPair(usage: displayUsagePayload, remaining: usageRemainingNumber)
        let dailyUsagePair = Self.resolveUsageQuotaPair(usage: packageUsagePayload, remaining: packageRemainingNumber)

        let renewal = Self.resolveRenewalText(package: state.package) ?? "--"
        let packageItems = Self.buildPackageSummaryItems(package: state.package)

        let usageLabel = "已用/总"
        let progressLabel = weeklyUsagePayload == nil ? "用量进度" : "本周用量进度"
        let progressPrefix = usageQuotaPair.map { "\($0.used)/\($0.total)" }

        let usage: String
        if let dailyUsagePair {
            usage = "\(dailyUsagePair.used)/\(dailyUsagePair.total)"
        } else if let usageQuotaPair {
            usage = "\(usageQuotaPair.used)/\(usageQuotaPair.total)"
        } else if let usedPercent {
            usage = String(format: "%.2f%%", usedPercent)
        } else if let totalCost = displayUsagePayload?.totalCost?.display {
            usage = "总消费: \(totalCost)"
        } else {
            usage = "--"
        }

        let metadata = CodexUsageInfoResponseViewModel.Metadata(
            httpStatusCode: httpResponse.statusCode,
            businessCode: decoded.code,
            message: decoded.msg,
            details: decoded.details
        )

        let viewModelState = CodexUsageInfoResponseViewModel.StateViewModel(
            email: state.user?.email,
            usageText: usage,
            remainingText: packageRemaining,
            dailyRemainingText: dailyRemaining,
            weeklyRemainingText: weeklyRemaining,
            usedPercent: usedPercent,
            renewalText: renewal,
            packageItems: packageItems,
            usageLabel: usageLabel,
            progressLabel: progressLabel,
            progressPrefix: progressPrefix,
            dailyUsagePayload: packageUsagePayload,
            weeklyUsagePayload: weeklyUsagePayload
        )

        return CodexUsageInfoResponseViewModel(
            request: request,
            metadata: metadata,
            state: viewModelState
        )
    }

    func fetchCodexUsageLogs(
        using request: CodexUsageLogsRequestViewModel
    ) async throws -> CodexUsageLogsResponseViewModel {
        let urlRequest = request.makeURLRequest()
        let data: Data
        let httpResponse: HTTPURLResponse

        do {
            let (responseData, response) = try await session.data(for: urlRequest)
            guard let typedResponse = response as? HTTPURLResponse else {
                throw CodexMonitorNetworkError.invalidHTTPResponse(source: .codex)
            }
            data = responseData
            httpResponse = typedResponse
        } catch let error as CodexMonitorNetworkError {
            throw error
        } catch {
            throw CodexMonitorNetworkError.transport(source: .codex, message: error.localizedDescription)
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw CodexMonitorNetworkError.httpStatus(source: .codex, statusCode: httpResponse.statusCode)
        }

        let decoded: CodexUsageLogsEnvelope
        do {
            decoded = try JSONDecoder().decode(CodexUsageLogsEnvelope.self, from: data)
        } catch {
            throw CodexMonitorNetworkError.decoding(
                source: .codex,
                message: error.localizedDescription,
                snippet: Self.rawSnippet(from: data)
            )
        }

        if let code = decoded.code, !Self.successBusinessCodes.contains(code) {
            let message = decoded.msg ?? decoded.error ?? decoded.details ?? "接口返回业务错误"
            throw CodexMonitorNetworkError.business(source: .codex, code: code, message: message)
        }

        if let errorText = decoded.error, !errorText.isEmpty {
            let details = decoded.details ?? decoded.msg ?? errorText
            throw CodexMonitorNetworkError.unauthorized(source: .codex, message: details)
        }

        guard let dataState = decoded.data else {
            throw CodexMonitorNetworkError.missingField(source: .codex, field: "data")
        }

        let rows = dataState.records.enumerated().map { index, item in
            buildUsageLogRow(item: item, fallbackIndex: index, page: dataState.page ?? request.page)
        }

        let panel = CodexUsageRecordsPanelViewModel(
            records: rows,
            page: max(1, dataState.page ?? request.page),
            pageSize: max(1, dataState.pageSize ?? request.pageSize),
            totalCount: dataState.totalCount,
            totalPages: dataState.totalPages,
            totalCostText: Self.currencyText(dataState.totalCost, precision: 4),
            pageCostText: Self.currencyText(dataState.pageCost, precision: 4),
            totalTokensText: Self.integerText(dataState.totalTokens),
            pageTokensText: Self.integerText(dataState.pageTokens),
            errorText: nil
        )

        let metadata = CodexUsageLogsResponseViewModel.Metadata(
            httpStatusCode: httpResponse.statusCode,
            businessCode: decoded.code,
            message: decoded.msg,
            details: decoded.details
        )

        return CodexUsageLogsResponseViewModel(
            request: request,
            metadata: metadata,
            state: CodexUsageLogsResponseViewModel.StateViewModel(panel: panel)
        )
    }

    func fetchAGIPackageInfo(
        using request: AGIPackageInfoRequestViewModel
    ) async throws -> AGIPackageInfoResponseViewModel {
        let urlRequest = request.makeURLRequest()
        let data: Data
        let httpResponse: HTTPURLResponse

        do {
            let (responseData, response) = try await session.data(for: urlRequest)
            guard let typedResponse = response as? HTTPURLResponse else {
                throw CodexMonitorNetworkError.invalidHTTPResponse(source: .agi)
            }
            data = responseData
            httpResponse = typedResponse
        } catch let error as CodexMonitorNetworkError {
            throw error
        } catch {
            throw CodexMonitorNetworkError.transport(source: .agi, message: error.localizedDescription)
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw CodexMonitorNetworkError.httpStatus(source: .agi, statusCode: httpResponse.statusCode)
        }

        let decoded: AGIPackageEnvelope
        do {
            decoded = try JSONDecoder().decode(AGIPackageEnvelope.self, from: data)
        } catch {
            throw CodexMonitorNetworkError.decoding(
                source: .agi,
                message: error.localizedDescription,
                snippet: Self.rawSnippet(from: data)
            )
        }

        if let code = decoded.code, !Self.successBusinessCodes.contains(code) {
            throw CodexMonitorNetworkError.business(
                source: .agi,
                code: code,
                message: decoded.message ?? "接口返回业务错误"
            )
        }

        guard let payload = decoded.data else {
            throw CodexMonitorNetworkError.missingField(source: .agi, field: "data")
        }

        let packages = payload.packages ?? []
        let totalBytes = payload.summary?.totalByte?.doubleValue
            ?? packages.compactMap { $0.byteTotal?.doubleValue }.reduce(0, +)
        let remainingBytes = payload.summary?.remainingByte?.doubleValue
            ?? packages.compactMap { $0.byteRemaining?.doubleValue }.reduce(0, +)
        let usedBytes = payload.summary?.usedByte?.doubleValue
            ?? packages.compactMap { $0.byteUsed?.doubleValue }.reduce(0, +)

        let usedPercent = Self.resolveByteUsedPercentage(total: totalBytes, used: usedBytes)
        let packageItems = Self.buildAGIPackageSummaryItems(packages: packages)
        let renewal = Self.resolveAGIRenewalText(summary: payload.summary, packages: packages) ?? "--"

        let usage: String
        if totalBytes > 0 {
            usage = "\(Self.formatByteCount(usedBytes))/\(Self.formatByteCount(totalBytes))"
        } else if usedBytes > 0 {
            usage = Self.formatByteCount(usedBytes)
        } else {
            usage = "--"
        }

        let metadata = AGIPackageInfoResponseViewModel.Metadata(
            httpStatusCode: httpResponse.statusCode,
            businessCode: decoded.code,
            message: decoded.message
        )

        let viewModelState = AGIPackageInfoResponseViewModel.StateViewModel(
            usageText: usage,
            remainingText: Self.formatByteCount(remainingBytes),
            usedPercent: usedPercent,
            renewalText: renewal,
            packageItems: packageItems
        )

        return AGIPackageInfoResponseViewModel(
            request: request,
            metadata: metadata,
            state: viewModelState
        )
    }

    private func buildUsageLogRow(
        item: CodexUsageLogPayload,
        fallbackIndex: Int,
        page: Int
    ) -> CodexUsageRecordViewModel {
        let fallbackID = "log-\(page)-\(fallbackIndex)"
        let id = item.id ?? item.requestID ?? fallbackID
        let timestampText = Self.logTimeText(item.timestamp)
        let tier = item.tier ?? "standard"
        let model = item.model ?? "未知模型"

        let totalTokensText = Self.integerText(item.totalTokens) ?? "--"
        let inputTokensText = Self.integerText(item.inputTokens) ?? "--"
        let cachedTokensText = Self.integerText(item.inputTokensCached) ?? "--"
        let outputTokensText = Self.integerText(item.outputTokens) ?? "--"
        let reasoningTokensText = Self.integerText(item.outputTokensReasoning)

        let tokenBreakdownText: String
        if let reasoningTokensText {
            tokenBreakdownText = "In \(inputTokensText) (cached \(cachedTokensText)) · Out \(outputTokensText) (think \(reasoningTokensText))"
        } else {
            tokenBreakdownText = "In \(inputTokensText) (cached \(cachedTokensText)) · Out \(outputTokensText)"
        }

        let totalCostText = Self.currencyText(item.totalCost, precision: 4) ?? "--"
        let inputCostText = Self.currencyText(item.inputCost, precision: 4) ?? "--"
        let outputCostText = Self.currencyText(item.outputCost, precision: 4) ?? "--"
        let cacheCostText = Self.currencyText(item.cacheReadCost, precision: 4) ?? "--"
        let costBreakdownText = "输入 \(inputCostText) · 输出 \(outputCostText) · 缓存 \(cacheCostText)"

        return CodexUsageRecordViewModel(
            id: id,
            timestampText: timestampText,
            modelText: model,
            tierText: tier,
            totalTokensText: totalTokensText,
            tokenBreakdownText: tokenBreakdownText,
            totalCostText: totalCostText,
            costBreakdownText: costBreakdownText,
            detailURL: item.detailURL,
            totalTokensValue: item.totalTokens,
            totalCostValue: item.totalCost
        )
    }

    private static let successBusinessCodes: Set<Int> = [0, 200]

    private static func rawSnippet(from data: Data) -> String {
        String(data: data, encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(120)
            .description ?? "无法读取响应内容"
    }

    private static func logTimeText(_ rawValue: String?) -> String {
        guard let rawValue, let date = parseAPIDate(rawValue) else {
            return rawValue ?? "--"
        }
        return logDateFormatter.string(from: date)
    }

    private static func integerText(_ value: Double?) -> String? {
        guard let value, value.isFinite else { return nil }
        let roundedValue = Int64(value.rounded())
        return integerFormatter.string(from: NSNumber(value: roundedValue)) ?? "\(roundedValue)"
    }

    private static func currencyText(_ value: Double?, precision: Int) -> String? {
        guard let value, value.isFinite else { return nil }
        return "$\(trimmedDecimal(value, maxDigits: precision))"
    }

    private static func trimmedDecimal(_ value: Double, maxDigits: Int) -> String {
        var text = String(format: "%.\(maxDigits)f", value)
        while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
            text.removeLast()
        }
        return text
    }

    private static func resolveUsedPercentage(usage: UsagePayload?, remaining: FlexibleNumber) -> Double? {
        if let fromAPI = usage?.usedPercentage?.doubleValue {
            return fromAPI
        }
        guard
            let totalQuota = usage?.totalQuota?.doubleValue,
            totalQuota > 0,
            let remainingQuota = remaining.doubleValue
        else {
            return nil
        }
        return (1 - (remainingQuota / totalQuota)) * 100
    }

    private static func resolveUsageQuotaPair(
        usage: UsagePayload?,
        remaining: FlexibleNumber
    ) -> (used: String, total: String)? {
        guard let usedQuota = resolveUsedQuota(usage: usage, remaining: remaining),
              let totalQuota = usage?.totalQuota?.doubleValue
        else {
            return nil
        }
        return (
            used: formatQuotaValue(usedQuota),
            total: formatQuotaValue(totalQuota)
        )
    }

    private static func resolveUsedQuota(usage: UsagePayload?, remaining: FlexibleNumber) -> Double? {
        guard
            let totalQuota = usage?.totalQuota?.doubleValue,
            totalQuota > 0,
            let remainingQuota = remaining.doubleValue
        else {
            return nil
        }
        return max(0, totalQuota - remainingQuota)
    }

    private static func formatQuotaValue(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        let rounded = value.rounded()
        if abs(value - rounded) < 0.005 {
            return "\(Int(rounded))"
        }
        return String(format: "%.2f", value)
    }

    private static func resolveByteUsedPercentage(total: Double?, used: Double?) -> Double? {
        guard let total, total > 0, let used else {
            return nil
        }
        return min(max((used / total) * 100, 0), 100)
    }

    private static func formatByteCount(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0 else {
            return "--"
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0

        let roundedValue = Int64(value.rounded())
        let numberText = formatter.string(from: NSNumber(value: roundedValue)) ?? "\(roundedValue)"
        return "\(numberText) B"
    }

    private static func resolveAGIRenewalText(
        summary: AGIPackageSummary?,
        packages: [AGIPackageItem]
    ) -> String? {
        let expiryText = summary?.latestExpireTime
            ?? packages.compactMap { $0.expireTime }.sorted().first
        guard let expiryText, let expiresDate = parseAPIDate(expiryText) else {
            return nil
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let renewalYear = calendar.component(.year, from: expiresDate)

        let absoluteFormatter = DateFormatter()
        absoluteFormatter.locale = Locale(identifier: "zh_CN")
        absoluteFormatter.timeZone = .current
        absoluteFormatter.dateFormat = renewalYear == currentYear ? "MM-dd HH:mm" : "yyyy-MM-dd HH:mm"

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.locale = Locale(identifier: "zh_CN")
        relativeFormatter.unitsStyle = .short

        let absolute = absoluteFormatter.string(from: expiresDate)
        let relative = relativeFormatter.localizedString(for: expiresDate, relativeTo: Date())
        return "\(absolute)（\(relative)）"
    }

    private static func buildAGIPackageSummaryItems(packages: [AGIPackageItem]) -> [SummaryPackageItem] {
        packages
            .compactMap { item -> (AGIPackageItem, Date)? in
                guard let expiryText = item.expireTime, let expiresDate = parseAPIDate(expiryText) else {
                    return nil
                }
                return (item, expiresDate)
            }
            .sorted(by: { $0.1 < $1.1 })
            .map { item, expiresDate in
                let createText = parseAPIDate(item.createTime ?? "").map { compactDateFormatter.string(from: $0) } ?? "--"
                let expireText = compactDateFormatter.string(from: expiresDate)
                let daysRemaining = max(
                    0,
                    Calendar.current.dateComponents(
                        [.day],
                        from: Calendar.current.startOfDay(for: Date()),
                        to: Calendar.current.startOfDay(for: expiresDate)
                    ).day ?? 0
                )

                let badgeTone: SummaryStatusTone
                if daysRemaining <= 1 {
                    badgeTone = .critical
                } else if daysRemaining <= 7 {
                    badgeTone = .warning
                } else {
                    badgeTone = .success
                }

                let reasonText = (item.reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? item.reason!
                    : "无备注"

                return SummaryPackageItem(
                    title: normalizeAGIPackageTitle(orderClass: item.orderClass, level: item.level),
                    subtitle: "开通 \(createText)  到期 \(expireText)  · \(reasonText)",
                    badgeText: daysRemaining == 0 ? "今天到期" : "剩\(daysRemaining)天",
                    badgeTone: badgeTone
                )
            }
    }

    private static func resolveRenewalText(package: PackagePayload?) -> String? {
        guard let package = selectDisplayPackage(from: package?.packages),
              let expiresAt = package.expiresAt,
              let expiresDate = parseAPIDate(expiresAt)
        else {
            return nil
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let renewalYear = calendar.component(.year, from: expiresDate)

        let absoluteFormatter = DateFormatter()
        absoluteFormatter.locale = Locale(identifier: "zh_CN")
        absoluteFormatter.timeZone = .current
        absoluteFormatter.dateFormat = renewalYear == currentYear ? "MM-dd HH:mm" : "yyyy-MM-dd HH:mm"

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.locale = Locale(identifier: "zh_CN")
        relativeFormatter.unitsStyle = .short

        let absolute = absoluteFormatter.string(from: expiresDate)
        let relative = relativeFormatter.localizedString(for: expiresDate, relativeTo: Date())
        return "\(absolute)（\(relative)）"
    }

    private static func buildPackageSummaryItems(package: PackagePayload?) -> [SummaryPackageItem] {
        activePackages(from: package?.packages).map { item, expiresDate in
            let startText = parseAPIDate(item.startAt ?? "").map { compactDateFormatter.string(from: $0) } ?? "--"
            let expireText = compactDateFormatter.string(from: expiresDate)
            let daysRemaining = max(
                0,
                Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: Date()),
                    to: Calendar.current.startOfDay(for: expiresDate)
                ).day ?? 0
            )

            let badgeTone: SummaryStatusTone
            if daysRemaining <= 1 {
                badgeTone = .critical
            } else if daysRemaining <= 7 {
                badgeTone = .warning
            } else {
                badgeTone = .success
            }

            return SummaryPackageItem(
                title: normalizePackageTitle(item.packageType),
                subtitle: "生效 \(startText)  到期 \(expireText)",
                badgeText: daysRemaining == 0 ? "今天到期" : "剩\(daysRemaining)天",
                badgeTone: badgeTone
            )
        }
    }

    private static func selectDisplayPackage(from packages: [PackageItem]?) -> PackageItem? {
        let now = Date()
        let candidates = activePackages(from: packages)

        if let upcoming = candidates
            .filter({ $0.1 >= now })
            .min(by: { $0.1 < $1.1 })
        {
            return upcoming.0
        }

        return candidates.max(by: { $0.1 < $1.1 })?.0
    }

    private static func activePackages(from packages: [PackageItem]?) -> [(PackageItem, Date)] {
        guard let packages, !packages.isEmpty else { return [] }

        let datedPackages = packages.compactMap { item -> (PackageItem, Date)? in
            guard let expiresAt = item.expiresAt, let expiresDate = parseAPIDate(expiresAt) else {
                return nil
            }
            return (item, expiresDate)
        }

        let activePackages = datedPackages.filter { ($0.0.packageStatus ?? "").lowercased() == "active" }
        let candidates = activePackages.isEmpty ? datedPackages : activePackages
        return candidates.sorted(by: { $0.1 < $1.1 })
    }

    private static func parseAPIDate(_ rawValue: String) -> Date? {
        let formatterWithFractionalSeconds = ISO8601DateFormatter()
        formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractionalSeconds.date(from: rawValue) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue)
    }

    private static func normalizePackageTitle(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.isEmpty else { return "未知套餐" }
        return rawValue
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeAGIPackageTitle(orderClass: String?, level: Int?) -> String {
        let order = orderClass?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (order, level) {
        case let (order?, level?) where !order.isEmpty:
            return "\(order) Lv\(level)"
        case let (order?, _) where !order.isEmpty:
            return order
        case let (_, level?):
            return "Lv\(level)"
        default:
            return "AGI 套餐"
        }
    }

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        return formatter
    }()

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private struct CodexUsageLogsEnvelope: Decodable {
    let code: Int?
    let msg: String?
    let error: String?
    let details: String?
    let data: CodexUsageLogsDataPayload?
}

private struct CodexUsageLogsDataPayload: Decodable {
    let records: [CodexUsageLogPayload]
    let page: Int?
    let pageSize: Int?
    let totalCount: Int?
    let totalPages: Int?
    let totalCost: Double?
    let pageCost: Double?
    let totalTokens: Double?
    let pageTokens: Double?

    enum CodingKeys: String, CodingKey {
        case list
        case logs
        case items
        case records
        case page
        case pageSize = "pageSize"
        case pageSizeSnake = "page_size"
        case total
        case totalCount = "totalCount"
        case totalCountSnake = "total_count"
        case totalPage = "totalPage"
        case totalPages = "totalPages"
        case totalPagesSnake = "total_pages"
        case totalCost = "totalCost"
        case totalCostSnake = "total_cost"
        case pageCost = "pageCost"
        case pageCostSnake = "page_cost"
        case amount
        case totalTokens = "totalTokens"
        case totalTokensSnake = "total_tokens"
        case pageTokens = "pageTokens"
        case pageTokensSnake = "page_tokens"
    }

    init(from decoder: Decoder) throws {
        if let list = try? [CodexUsageLogPayload](from: decoder) {
            records = list
            page = nil
            pageSize = nil
            totalCount = list.count
            totalPages = nil
            totalCost = nil
            pageCost = nil
            totalTokens = nil
            pageTokens = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        records = try container.decodeIfPresent([CodexUsageLogPayload].self, forKey: .list)
            ?? container.decodeIfPresent([CodexUsageLogPayload].self, forKey: .logs)
            ?? container.decodeIfPresent([CodexUsageLogPayload].self, forKey: .items)
            ?? container.decodeIfPresent([CodexUsageLogPayload].self, forKey: .records)
            ?? []

        page = Self.decodeIntLike(from: container, keys: [.page])
        pageSize = Self.decodeIntLike(from: container, keys: [.pageSize, .pageSizeSnake])
        totalCount = Self.decodeIntLike(from: container, keys: [.total, .totalCount, .totalCountSnake])
        totalPages = Self.decodeIntLike(from: container, keys: [.totalPage, .totalPages, .totalPagesSnake])

        totalCost = Self.decodeDoubleLike(from: container, keys: [.totalCost, .totalCostSnake, .amount])
        pageCost = Self.decodeDoubleLike(from: container, keys: [.pageCost, .pageCostSnake])
        totalTokens = Self.decodeDoubleLike(from: container, keys: [.totalTokens, .totalTokensSnake])
        pageTokens = Self.decodeDoubleLike(from: container, keys: [.pageTokens, .pageTokensSnake])
    }

    private static func decodeIntLike(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int? {
        for key in keys {
            if let direct = try? container.decode(Int.self, forKey: key) {
                return direct
            }
            if let flexible = try? container.decode(FlexibleNumber.self, forKey: key),
               let double = flexible.doubleValue,
               double.isFinite
            {
                return Int(double.rounded())
            }
            if let stringValue = try? container.decode(String.self, forKey: key),
               let parsed = Int(stringValue)
            {
                return parsed
            }
        }
        return nil
    }

    private static func decodeDoubleLike(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Double? {
        for key in keys {
            if let direct = try? container.decode(Double.self, forKey: key) {
                return direct
            }
            if let flexible = try? container.decode(FlexibleNumber.self, forKey: key),
               let value = flexible.doubleValue,
               value.isFinite
            {
                return value
            }
            if let stringValue = try? container.decode(String.self, forKey: key),
               let parsed = Double(stringValue)
            {
                return parsed
            }
        }
        return nil
    }
}

private struct CodexUsageLogPayload: Decodable {
    let id: String?
    let requestID: String?
    let timestamp: String?
    let model: String?
    let tier: String?
    let totalTokens: Double?
    let inputTokens: Double?
    let inputTokensCached: Double?
    let outputTokens: Double?
    let outputTokensReasoning: Double?
    let totalCost: Double?
    let inputCost: Double?
    let outputCost: Double?
    let cacheReadCost: Double?
    let detailURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case logID = "log_id"
        case requestID = "request_id"
        case requestId = "requestId"
        case createdAt = "created_at"
        case createdAtCamel = "createdAt"
        case time
        case timestamp
        case model
        case modelName = "model_name"
        case modelNameCamel = "modelName"
        case serviceTier = "service_tier"
        case serviceTierCamel = "serviceTier"
        case tier
        case totalTokens = "total_tokens"
        case totalTokensCamel = "totalTokens"
        case inputTokens = "input_tokens"
        case inputTokensCamel = "inputTokens"
        case inputTokensCached = "input_tokens_cached"
        case inputTokensCachedCamel = "inputTokensCached"
        case outputTokens = "output_tokens"
        case outputTokensCamel = "outputTokens"
        case outputTokensReasoning = "output_tokens_reasoning"
        case outputTokensReasoningCamel = "outputTokensReasoning"
        case totalCost = "total_cost"
        case totalCostCamel = "totalCost"
        case inputCost = "input_cost"
        case inputCostCamel = "inputCost"
        case outputCost = "output_cost"
        case outputCostCamel = "outputCost"
        case cacheReadCost = "cache_read_cost"
        case cacheReadCostCamel = "cacheReadCost"
        case detailURL = "detail_url"
        case detailURLCamel = "detailUrl"
        case detailURLCamel2 = "detailURL"
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .logID)
        requestID = try container.decodeIfPresent(String.self, forKey: .requestID)
            ?? container.decodeIfPresent(String.self, forKey: .requestId)
        timestamp = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .createdAtCamel)
            ?? container.decodeIfPresent(String.self, forKey: .time)
            ?? container.decodeIfPresent(String.self, forKey: .timestamp)
        model = try container.decodeIfPresent(String.self, forKey: .model)
            ?? container.decodeIfPresent(String.self, forKey: .modelName)
            ?? container.decodeIfPresent(String.self, forKey: .modelNameCamel)
        tier = try container.decodeIfPresent(String.self, forKey: .tier)
            ?? container.decodeIfPresent(String.self, forKey: .serviceTier)
            ?? container.decodeIfPresent(String.self, forKey: .serviceTierCamel)

        totalTokens = Self.decodeFlexibleDouble(container: container, snake: .totalTokens, camel: .totalTokensCamel)
        inputTokens = Self.decodeFlexibleDouble(container: container, snake: .inputTokens, camel: .inputTokensCamel)
        inputTokensCached = Self.decodeFlexibleDouble(container: container, snake: .inputTokensCached, camel: .inputTokensCachedCamel)
        outputTokens = Self.decodeFlexibleDouble(container: container, snake: .outputTokens, camel: .outputTokensCamel)
        outputTokensReasoning = Self.decodeFlexibleDouble(container: container, snake: .outputTokensReasoning, camel: .outputTokensReasoningCamel)

        totalCost = Self.decodeFlexibleDouble(container: container, snake: .totalCost, camel: .totalCostCamel)
        inputCost = Self.decodeFlexibleDouble(container: container, snake: .inputCost, camel: .inputCostCamel)
        outputCost = Self.decodeFlexibleDouble(container: container, snake: .outputCost, camel: .outputCostCamel)
        cacheReadCost = Self.decodeFlexibleDouble(container: container, snake: .cacheReadCost, camel: .cacheReadCostCamel)

        detailURL = try container.decodeIfPresent(String.self, forKey: .detailURL)
            ?? container.decodeIfPresent(String.self, forKey: .detailURLCamel)
            ?? container.decodeIfPresent(String.self, forKey: .detailURLCamel2)
            ?? container.decodeIfPresent(String.self, forKey: .url)
    }

    private static func decodeFlexibleDouble(
        container: KeyedDecodingContainer<CodingKeys>,
        snake: CodingKeys,
        camel: CodingKeys
    ) -> Double? {
        if let flexible = try? container.decode(FlexibleNumber.self, forKey: snake),
           let value = flexible.doubleValue,
           value.isFinite
        {
            return value
        }
        if let flexible = try? container.decode(FlexibleNumber.self, forKey: camel),
           let value = flexible.doubleValue,
           value.isFinite
        {
            return value
        }
        if let direct = try? container.decode(Double.self, forKey: snake) {
            return direct
        }
        if let direct = try? container.decode(Double.self, forKey: camel) {
            return direct
        }
        return nil
    }
}
