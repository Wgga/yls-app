import AppKit
import MarkdownUI
import UniformTypeIdentifiers
import SwiftUI

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}

private final class CustomSkinSliderHitView: NSView {
    var knobDiameter: CGFloat = 24
    var onValueChange: ((Double) -> Void)?

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        updateValue(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateValue(with: event)
    }

    private func updateValue(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let trackInset = knobDiameter / 2
        let availableWidth = max(1, bounds.width - knobDiameter)
        let rawValue = Double((point.x - trackInset) / availableWidth)
        onValueChange?(max(0, min(1, rawValue)))
    }
}

private struct CustomSkinSliderHitLayer: NSViewRepresentable {
    @Binding var value: Double
    let knobDiameter: CGFloat
    let onChanged: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, onChanged: onChanged)
    }

    func makeNSView(context: Context) -> CustomSkinSliderHitView {
        let view = CustomSkinSliderHitView()
        view.knobDiameter = knobDiameter
        view.onValueChange = { context.coordinator.setValue($0) }
        return view
    }

    func updateNSView(_ view: CustomSkinSliderHitView, context: Context) {
        context.coordinator.value = $value
        context.coordinator.onChanged = onChanged
        view.knobDiameter = knobDiameter
        view.onValueChange = { context.coordinator.setValue($0) }
    }

    final class Coordinator {
        var value: Binding<Double>
        var onChanged: (() -> Void)?

        init(value: Binding<Double>, onChanged: (() -> Void)?) {
            self.value = value
            self.onChanged = onChanged
        }

        func setValue(_ newValue: Double) {
            value.wrappedValue = max(0, min(1, newValue))
            onChanged?()
        }
    }
}

extension View {
    @ViewBuilder
    func contentMaterialSurface(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        self
            .background {
                ZStack {
                    shape
                        .fill(.regularMaterial)
                    shape
                        .fill(tint)
                }
            }
            .overlay {
                shape.stroke(.quaternary, lineWidth: 0.65)
            }
    }

    func summaryDashboardSurface(
        cornerRadius: CGFloat,
        colorScheme: ColorScheme,
        elevated: Bool = false,
        useCustomSkin: Bool = false,
        customAccent: Color = .clear
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let fill: Color
        let border: Color

        if useCustomSkin {
            if colorScheme == .dark {
                fill = elevated ? Color.white.opacity(0.07) : Color.white.opacity(0.05)
                border = customAccent.opacity(0.30)
            } else {
                fill = elevated ? Color.white.opacity(0.98) : Color.white.opacity(0.92)
                border = customAccent.opacity(0.32)
            }
        } else {
            if colorScheme == .dark {
                fill = elevated ? Color.white.opacity(0.07) : Color.white.opacity(0.05)
                border = Color.white.opacity(0.11)
            } else {
                fill = elevated ? Color.white.opacity(0.98) : Color.white.opacity(0.92)
                border = Color.black.opacity(0.08)
            }
        }

        return self
            .background(shape.fill(fill))
            .overlay {
                shape.stroke(border, lineWidth: 0.8)
            }
    }
}

struct StyleAxisOptionButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity, minHeight: 30)
            .padding(.horizontal, 8)
            .contentMaterialSurface(
                cornerRadius: 10,
                tint: isSelected
                    ? .secondary.opacity(0.16)
                    : (isHovered ? .primary.opacity(0.08) : .clear)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.tertiary, lineWidth: 0.8)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct StatusStyleQuickPicker: View {
    let style: StatusDisplayStyle
    let onSelect: (StatusDisplayStyle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            axisRow(title: "范围") {
                ForEach(StatusDisplayStyle.TimeRange.allCases, id: \.rawValue) { option in
                    StyleAxisOptionButton(
                        title: option.title,
                        systemImage: option.symbol,
                        isSelected: style.timeRange == option
                    ) {
                        update(
                            timeRange: option,
                            metricKind: style.metricKind,
                            presentationKind: style.presentationKind
                        )
                    }
                }
            }

            axisRow(title: "指标") {
                ForEach(StatusDisplayStyle.MetricKind.allCases, id: \.rawValue) { option in
                    StyleAxisOptionButton(
                        title: option.title,
                        systemImage: option.symbol,
                        isSelected: style.metricKind == option
                    ) {
                        update(
                            timeRange: style.timeRange,
                            metricKind: option,
                            presentationKind: style.presentationKind
                        )
                    }
                }
            }

            axisRow(title: "展示") {
                ForEach(StatusDisplayStyle.PresentationKind.allCases, id: \.rawValue) { option in
                    StyleAxisOptionButton(
                        title: option.title,
                        systemImage: option.symbol,
                        isSelected: style.presentationKind == option
                    ) {
                        update(
                            timeRange: style.timeRange,
                            metricKind: style.metricKind,
                            presentationKind: option
                        )
                    }
                }
            }
        }
    }

    private func update(
        timeRange: StatusDisplayStyle.TimeRange,
        metricKind: StatusDisplayStyle.MetricKind,
        presentationKind: StatusDisplayStyle.PresentationKind
    ) {
        let resolved = StatusDisplayStyle.resolve(
            timeRange: timeRange,
            metricKind: metricKind,
            presentationKind: presentationKind
        )
        guard resolved != style else { return }
        onSelect(resolved)
    }

    private func axisRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                content()
            }
        }
    }
}

struct WeightedMetricRowLayout: Layout {
    let weights: [CGFloat]
    let spacing: CGFloat

    init(weights: [CGFloat], spacing: CGFloat = 8) {
        self.weights = weights
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = resolvedWidth(for: proposal, subviews: subviews)
        let widths = distributedWidths(for: availableWidth, count: subviews.count)
        let maxHeight = subviews.enumerated().reduce(CGFloat.zero) { current, pair in
            let (index, subview) = pair
            let size = subview.sizeThatFits(
                ProposedViewSize(width: widths[index], height: proposal.height)
            )
            return max(current, size.height)
        }
        return CGSize(width: availableWidth, height: maxHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let widths = distributedWidths(for: bounds.width, count: subviews.count)
        var currentX = bounds.minX

        for (index, subview) in subviews.enumerated() {
            let width = widths[index]
            subview.place(
                at: CGPoint(x: currentX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            currentX += width + spacing
        }
    }

    private func resolvedWidth(for proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        if let width = proposal.width {
            return width
        }

        let intrinsicWidth = subviews.reduce(CGFloat.zero) { current, subview in
            current + subview.sizeThatFits(.unspecified).width
        }
        let totalSpacing = spacing * CGFloat(max(subviews.count - 1, 0))
        return intrinsicWidth + totalSpacing
    }

    private func distributedWidths(for totalWidth: CGFloat, count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }

        let totalSpacing = spacing * CGFloat(max(count - 1, 0))
        let contentWidth = max(0, totalWidth - totalSpacing)
        let activeWeights = Array(weights.prefix(count))
        let weightSum = max(activeWeights.reduce(CGFloat.zero, +), 1)

        return activeWeights.map { contentWidth * ($0 / weightSum) }
    }
}

struct SourceSummaryGroupView: View {
    let model: SourceSummaryGroupViewModel
    let codexDashboard: CodexDashboardMetrics
    let onToggle: (() -> Void)?
    let onOpenPricing: (() -> Void)?
    let successBadgeColor: Color
    let useCustomSkin: Bool
    let customSkinAccentColor: Color
    @Environment(\.colorScheme) private var colorScheme

    init(
        model: SourceSummaryGroupViewModel,
        codexDashboard: CodexDashboardMetrics = .empty,
        successBadgeColor: Color = Color(nsColor: .systemGreen),
        useCustomSkin: Bool = false,
        customSkinAccentColor: Color = Color(nsColor: .systemGreen),
        onOpenPricing: (() -> Void)? = nil,
        onToggle: (() -> Void)? = nil
    ) {
        self.model = model
        self.codexDashboard = codexDashboard
        self.successBadgeColor = successBadgeColor
        self.useCustomSkin = useCustomSkin
        self.customSkinAccentColor = customSkinAccentColor
        self.onOpenPricing = onOpenPricing
        self.onToggle = onToggle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { onToggle?() }) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: model.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Text(model.source.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)

                    if model.source == .codex {
                        purchaseBadgeButton()
                    }

                    Spacer(minLength: 8)

                    Text("余: \(displayRemainingValue)")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    statusBadgeText(model.statusText, tone: model.statusTone)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if shouldShowFooterText {
                Text(displayFooterText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if model.isExpanded {
                if model.source == .codex {
                    codexExpandedContent
                } else if model.source == .agi {
                    agiExpandedContent
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .summaryDashboardSurface(
            cornerRadius: 16,
            colorScheme: colorScheme,
            useCustomSkin: useCustomSkin,
            customAccent: customSkinAccentColor
        )
    }

    private var codexExpandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            packageSummaryList

            WeightedMetricRowLayout(weights: [1, 1], spacing: 8) {
                quotaMetricCard(
                    title: "今日配额",
                    symbol: "chart.bar",
                    ratioText: quotaRatioText(used: codexDashboard.dailyUsedQuota, total: codexDashboard.dailyTotalQuota)
                        ?? currencyRatioText(from: model.usageValue),
                    percentText: quotaPercentText(
                        directPercent: codexDashboard.dailyUsedPercent,
                        used: codexDashboard.dailyUsedQuota,
                        total: codexDashboard.dailyTotalQuota
                    ) ?? "--",
                    progress: quotaProgress(
                        directPercent: codexDashboard.dailyUsedPercent,
                        used: codexDashboard.dailyUsedQuota,
                        total: codexDashboard.dailyTotalQuota
                    )
                )

                quotaMetricCard(
                    title: "本周配额",
                    symbol: "calendar",
                    ratioText: quotaRatioText(used: codexDashboard.weeklyUsedQuota, total: codexDashboard.weeklyTotalQuota)
                        ?? currencyRatioText(from: model.progressPrefix ?? model.usageValue),
                    percentText: quotaPercentText(
                        directPercent: codexDashboard.weeklyUsedPercent,
                        used: codexDashboard.weeklyUsedQuota,
                        total: codexDashboard.weeklyTotalQuota
                    ) ?? (model.progressValue == "--" ? "--" : model.progressValue),
                    progress: quotaProgress(
                        directPercent: codexDashboard.weeklyUsedPercent,
                        used: codexDashboard.weeklyUsedQuota,
                        total: codexDashboard.weeklyTotalQuota,
                        fallback: model.progress ?? 0
                    )
                )
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(Array(codexMetricTiles.enumerated()), id: \.offset) { _, tile in
                    metricCard(title: tile.title, value: tile.value, symbol: tile.symbol, tint: tile.tint)
                }
            }
        }
    }

    private var agiExpandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            packageSummaryList

            WeightedMetricRowLayout(weights: [1, 1], spacing: 8) {
                ForEach(Array(agiSummaryCards.enumerated()), id: \.offset) { _, card in
                    metricCard(
                        title: card.title,
                        value: card.value,
                        lineLimit: card.lineLimit,
                        symbol: card.symbol,
                        tint: card.tint
                    )
                }
            }

            usageProgressCard(
                title: model.progressLabel,
                prefixText: model.progressPrefix,
                valueText: model.progressValue,
                progress: model.progress ?? 0
            )
        }
    }

    private var packageSummaryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            let items = displayPackageItems
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                packageSummaryCard(item)
            }
        }
    }

    private func packageSummaryCard(_ item: SummaryPackageItem) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(packageTitleText(for: item))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !item.badgeText.isEmpty {
                        statusBadgeText(item.badgeText, tone: item.badgeTone)
                    }
                }

                Text(item.subtitle)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(packageTrailingText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .summaryDashboardSurface(
            cornerRadius: 13,
            colorScheme: colorScheme,
            elevated: true,
            useCustomSkin: useCustomSkin,
            customAccent: customSkinAccentColor
        )
    }

    private var displayPackageItems: [SummaryPackageItem] {
        if !model.packageItems.isEmpty {
            return model.packageItems
        }

        return [
            SummaryPackageItem(
                title: model.source == .codex ? "未获取套餐数据" : "AGI 套餐",
                subtitle: model.source == .codex ? model.footerText : "到期 \(model.renewalValue)",
                badgeText: "",
                badgeTone: .neutral
            ),
        ]
    }

    private func packageTitleText(for item: SummaryPackageItem) -> String {
        switch model.source {
        case .codex:
            return "\(item.title) 订阅"
        case .agi:
            return item.title
        }
    }

    private var packageTrailingText: String {
        switch model.source {
        case .codex:
            return codexDailyLimitText
        case .agi:
            return agiPackageLimitText
        }
    }

    private var codexDailyLimitText: String {
        guard let dailyTotalQuota = codexDashboard.dailyTotalQuota, dailyTotalQuota.isFinite else {
            return "--/天"
        }
        return "\(currencyAmountText(dailyTotalQuota))/天"
    }

    private var agiPackageLimitText: String {
        let parts = model.usageValue.split(separator: "/", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2, !parts[1].isEmpty else {
            return "--"
        }
        return formattedAGIByteText(parts[1])
    }

    private func quotaMetricCard(
        title: String,
        symbol: String,
        ratioText: String,
        percentText: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Text(ratioText)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(percentText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            quotaProgressBar(progress: progress)
            .frame(height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .summaryDashboardSurface(
            cornerRadius: 13,
            colorScheme: colorScheme,
            elevated: true,
            useCustomSkin: useCustomSkin,
            customAccent: customSkinAccentColor
        )
    }

    @ViewBuilder
    private func quotaProgressBar(progress: Double) -> some View {
        let clamped = max(0, min(1, progress))
        let trackColor = colorScheme == .dark ? Color.white.opacity(0.16) : Color(hex: 0xF1F1F1)
        let startColor = colorScheme == .dark ? Color.white.opacity(0.90) : Color(hex: 0xD8E4F7)
        let endColor = colorScheme == .dark ? Color.accentColor.opacity(0.45) : Color(hex: 0x89AEE8)
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                startColor,
                                endColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, proxy.size.width * clamped))
            }
        }
    }

    private struct CodexTile {
        let title: String
        let value: String
        let symbol: String?
        let tint: Color?
    }

    private var codexMetricTiles: [CodexTile] {
        [
            CodexTile(
                title: "今日请求次数",
                value: codexDashboard.requestCount.map { "\($0) 次" } ?? "--",
                symbol: "arrow.triangle.2.circlepath",
                tint: Color(hex: 0x3B82F6)
            ),
            CodexTile(
                title: "今日消耗额度",
                value: codexDashboard.totalCost.map(currencyAmountText) ?? "--",
                symbol: "creditcard",
                tint: Color(hex: 0x57BF71)
            ),
            CodexTile(
                title: "今日消耗 Token",
                value: tokenText(codexDashboard.totalTokens),
                symbol: "cpu",
                tint: Color(hex: 0xA87AE8)
            ),
            CodexTile(
                title: "输入 Token",
                value: tokenText(codexDashboard.inputTokens),
                symbol: "arrow.down.left",
                tint: Color(hex: 0x7BA3FF)
            ),
            CodexTile(
                title: "缓存 Token",
                value: tokenText(codexDashboard.cachedInputTokens),
                symbol: "shippingbox",
                tint: Color(hex: 0x69C27D)
            ),
            CodexTile(
                title: "输出 Token",
                value: tokenText(codexDashboard.outputTokens),
                symbol: "arrow.up.right",
                tint: Color(hex: 0xFFA95E)
            ),
        ]
    }

    private func usageProgressCard(
        title: String,
        prefixText: String?,
        valueText: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if let prefixText, !prefixText.isEmpty {
                    Text(prefixText)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Text(valueText)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            quotaProgressBar(progress: progress)
                .frame(height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .summaryDashboardSurface(cornerRadius: 13, colorScheme: colorScheme, elevated: true)
    }

    private struct MetricCardContent {
        let title: String
        let value: String
        let lineLimit: Int
        let symbol: String?
        let tint: Color?

        init(
            title: String,
            value: String,
            lineLimit: Int,
            symbol: String? = nil,
            tint: Color? = nil
        ) {
            self.title = title
            self.value = value
            self.lineLimit = lineLimit
            self.symbol = symbol
            self.tint = tint
        }
    }

    private var agiSummaryCards: [MetricCardContent] {
        [
            MetricCardContent(
                title: "剩余字节",
                value: displayRemainingValue,
                lineLimit: 1,
                symbol: "tray.full",
                tint: Color(hex: 0x57BF71)
            ),
            MetricCardContent(
                title: model.usageLabel,
                value: formattedAGIUsageValue,
                lineLimit: 1,
                symbol: "chart.bar",
                tint: Color(hex: 0x3B82F6)
            ),
        ]
    }

    private var displayRemainingValue: String {
        guard model.source == .agi else {
            return model.remainingValue
        }
        return formattedAGIByteText(model.remainingValue)
    }

    private var displayFooterText: String {
        guard model.source == .codex, model.footerText == "请先设置 API Key" else {
            return model.footerText
        }
        return "请先设置 Codex API Key"
    }

    private var shouldShowFooterText: Bool {
        model.source != .codex && !displayFooterText.isEmpty
    }

    private var formattedAGIUsageValue: String {
        let parts = model.usageValue.split(separator: "/", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2 else {
            return formattedAGIByteText(model.usageValue)
        }
        return "\(formattedAGIByteText(parts[0]))/\(formattedAGIByteText(parts[1]))"
    }

    private func formattedAGIByteText(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "--" else {
            return trimmed.isEmpty ? "--" : trimmed
        }

        let hasByteSuffix = trimmed.uppercased().hasSuffix("B")
        let numericText = (hasByteSuffix ? String(trimmed.dropLast()) : trimmed)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard let value = Double(numericText), value.isFinite else {
            return trimmed
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0

        let roundedValue = Int64(value.rounded())
        let numberText = formatter.string(from: NSNumber(value: roundedValue)) ?? "\(roundedValue)"
        return hasByteSuffix ? "\(numberText) B" : numberText
    }

    private func quotaRatioText(used: Double?, total: Double?) -> String? {
        guard let used, let total, used.isFinite, total.isFinite else {
            return nil
        }
        return "\(currencyAmountText(used)) / \(currencyAmountText(total))"
    }

    private func quotaPercentText(directPercent: Double?, used: Double?, total: Double?) -> String? {
        if let directPercent, directPercent.isFinite {
            return String(format: "%.0f%%", max(0, min(100, directPercent)))
        }
        guard let used, let total, total > 0, used.isFinite, total.isFinite else {
            return nil
        }
        let resolved = (used / total) * 100
        guard resolved.isFinite else { return nil }
        return String(format: "%.0f%%", max(0, min(100, resolved)))
    }

    private func quotaProgress(
        directPercent: Double?,
        used: Double?,
        total: Double?,
        fallback: Double = 0
    ) -> Double {
        if let directPercent, directPercent.isFinite {
            return max(0, min(1, directPercent / 100))
        }
        guard let used, let total, total > 0, used.isFinite, total.isFinite else {
            return max(0, min(1, fallback))
        }
        let ratio = used / total
        guard ratio.isFinite else {
            return max(0, min(1, fallback))
        }
        return max(0, min(1, ratio))
    }

    private func currencyRatioText(from raw: String) -> String {
        let parts = raw.split(separator: "/", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if parts.count == 2 {
            return "\(currencyAmountText(from: parts[0])) / \(currencyAmountText(from: parts[1]))"
        }
        return currencyAmountText(from: raw)
    }

    private func currencyAmountText(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private func currencyAmountText(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "--" || trimmed.hasPrefix("$") {
            return trimmed
        }
        if let number = Double(trimmed), number.isFinite {
            return currencyAmountText(number)
        }
        return trimmed
    }

    private func tokenText(_ rawValue: Double?) -> String {
        guard let rawValue, rawValue.isFinite else { return "--" }
        let absolute = abs(rawValue)
        if absolute >= 1_000_000 {
            return "\(trimmedScaled(rawValue / 1_000_000)) M"
        }
        if absolute >= 1_000 {
            return "\(trimmedScaled(rawValue / 1_000)) k"
        }
        return "\(Int(rawValue.rounded()))"
    }

    private func trimmedScaled(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        var text = String(format: "%.2f", value)
        while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
            text.removeLast()
        }
        return text
    }

    private func metricCard(
        title: String,
        value: String,
        lineLimit: Int = 1,
        symbol: String? = nil,
        tint: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let symbol {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill((tint ?? .secondary).opacity(0.18))
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(tint ?? .secondary)
                    }
                    .frame(width: 30, height: 30)
                    .padding(.bottom, 1)
            }

            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .summaryDashboardSurface(
                cornerRadius: 13,
                colorScheme: colorScheme,
                elevated: true,
                useCustomSkin: useCustomSkin,
                customAccent: customSkinAccentColor
            )
    }

    private func statusBadgeText(_ text: String, tone: SummaryStatusTone) -> some View {
        let palette = badgePalette(for: tone)
        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(palette.fill)
            .overlay {
                Capsule().stroke(palette.border, lineWidth: 0.8)
            }
            .clipShape(Capsule())
    }

    private func purchaseBadgeButton() -> some View {
        Button(action: { onOpenPricing?() }) {
            Text("去购买")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(successBadgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(successBadgeColor.opacity(0.22))
                .overlay {
                    Capsule().stroke(successBadgeColor.opacity(0.32), lineWidth: 0.8)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func badgePalette(for tone: SummaryStatusTone) -> (text: Color, fill: Color, border: Color) {
        if tone == .success {
            return (
                successBadgeColor,
                successBadgeColor.opacity(0.12),
                successBadgeColor.opacity(0.22)
            )
        }
        return (tone.swiftUIColor, tone.swiftUIFillColor, tone.swiftUIBorderColor)
    }
}

private enum DashboardTab: String, CaseIterable {
    case usageOverview
    case usageRecords
    case codexSwitch
    case scheduledTasks

    var title: String {
        switch self {
        case .usageOverview:
            return "使用情况"
        case .usageRecords:
            return "使用记录"
        case .codexSwitch:
            return "Codex Switch"
        case .scheduledTasks:
            return "定时任务"
        }
    }

    var systemImage: String {
        switch self {
        case .usageOverview:
            return "chart.bar"
        case .usageRecords:
            return "clock.arrow.circlepath"
        case .codexSwitch:
            return "arrow.left.arrow.right"
        case .scheduledTasks:
            return "alarm"
        }
    }
}

private enum ScheduledTaskRepeatKind: String, CaseIterable {
    case daily
    case weekly
    case monthly

    var title: String {
        switch self {
        case .daily:
            return "每天"
        case .weekly:
            return "每周"
        case .monthly:
            return "每月"
        }
    }
}

private enum ScheduledTaskReminderType: String {
    case popup

    var title: String {
        switch self {
        case .popup:
            return "弹窗提醒"
        }
    }

    var systemImage: String {
        switch self {
        case .popup:
            return "macwindow.on.rectangle"
        }
    }
}

private enum ScheduledTaskAction: String, CaseIterable {
    case none
    case shutdown

    var title: String {
        switch self {
        case .none:
            return "仅提醒"
        case .shutdown:
            return "确认后关机"
        }
    }

    var systemImage: String {
        switch self {
        case .none:
            return "bell"
        case .shutdown:
            return "power"
        }
    }
}

struct MonitorDashboardShellView: View {
    let model: StatusSummaryViewModel
    let onTogglePanelMode: (() -> Void)?
    let onToggleEmail: (() -> Void)?
    let onRefresh: (() -> Void)?
    let onSelectStatisticsMode: ((StatisticsDisplayMode) -> Void)?
    let onSelectSource: ((PackageSource) -> Void)?
    let onSetAPIKey: ((PackageSource, String) -> Void)?
    let onSetInterval: ((Double) -> Void)?
    let onOpenDashboard: (() -> Void)?
    let onOpenPricing: (() -> Void)?
    let onSelectDisplayStyle: ((StatusDisplayStyle) -> Void)?
    let onToggleSourceGroup: ((PackageSource) -> Void)?
    let onToggleLaunchAtLogin: ((Bool) -> Void)?
    let onConfigureMCP: ((Bool, UInt16) -> Void)?
    let onSetStatusBarColor: ((StatusBarForegroundMode, String) -> Void)?
    let onSelectUsageLogsPage: ((Int) -> Void)?
    let onOpenUsageLogDetail: ((String) -> Void)?

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var selectedTab: DashboardTab = .usageOverview
    @State private var isCodexPanelExpanded = true
    @State private var isStatusBarSettingsExpanded = false
    @State private var codexAPIKeyDraft = ""
    @State private var agiAPIKeyDraft = ""
    @FocusState private var focusedAPIKeyField: APIKeyInputField?
    @State private var intervalSecondsDraft = 5
    @State private var mcpEnabledDraft = false
    @State private var mcpPortDraft = "\(AppMeta.defaultMCPPort)"
    @State private var statusBarAutoAdaptDraft = true
    @State private var statusBarManualColorDraft = Color.white
    @State private var isSkinSettingsPageVisible = false
    @AppStorage(DefaultsKey.scheduledTaskConfigured) private var scheduledTaskConfigured = false
    @State private var scheduledTasks: [ScheduledTaskItem] = ScheduledTaskItem.loadAll()
    @State private var isScheduledTaskMenuPresented = false
    @State private var presentedScheduledTaskMenuID: String?
    @State private var isScheduledTaskEditorVisible = false
    @State private var isEditingScheduledTask = false
    @State private var editingScheduledTaskID: String?
    @State private var scheduledTaskDraftHourText = "08"
    @State private var scheduledTaskDraftMinuteText = "00"
    @State private var scheduledTaskDraftRepeatKindRawValue = ScheduledTaskRepeatKind.daily.rawValue
    @State private var scheduledTaskDraftRepeatDayText = "1"
    @State private var scheduledTaskDraftTitle = ""
    @State private var scheduledTaskDraftDescription = ""
    @State private var scheduledTaskDraftActionRawValue = ScheduledTaskAction.none.rawValue
    @State private var scheduledTaskDraftCancelButtonTitle = "再卷一会儿"
    @State private var scheduledTaskDraftConfirmButtonTitle = "准点下班"
    @State private var scheduledTaskDraftIconImageDataBase64: String?
    @State private var codexSwitchProviders: [CodexSwitchProviderItem] = CodexSwitchProviderItem.loadAll()
    @State private var isCodexSwitchAddProviderVisible = false
    @State private var codexSwitchDraftScopeRawValue = CodexSwitchProviderItem.Scope.appSpecific.rawValue
    @State private var codexSwitchDraftPreset = "OpenAI"
    @State private var codexSwitchDraftName = ""
    @State private var codexSwitchDraftEndpoint = ""
    @State private var codexSwitchDraftAPIKey = ""
    @State private var codexSwitchDraftWebsite = ""
    @State private var codexSwitchDraftNotes = ""
    @State private var codexSwitchDraftUseFullURL = false
    @State private var codexSwitchDraftModelName = "gpt-5.4"
    @State private var codexSwitchDraftWriteGlobalConfig = true
    @State private var codexSwitchDraftCompressionThresholdText = "900000"
    @State private var codexSwitchDraftOneMillionContext = false
    @State private var codexSwitchDraftUseStandaloneTestConfig = false
    @State private var codexSwitchDraftTestPanelExpanded = true
    @State private var codexSwitchDraftTestModel = ""
    @State private var codexSwitchDraftTestTimeoutText = "45"
    @State private var codexSwitchDraftTestDegradeThresholdText = "6000"
    @State private var codexSwitchDraftTestPrompt = "Who are you?"
    @State private var codexSwitchDraftTestMaxRetriesText = "2"
    @AppStorage("skin_source_option") private var selectedSkinSourceRawValue = SkinSourceOption.official.rawValue
    @AppStorage("skin_theme_option") private var selectedSkinThemeRawValue = SkinThemeOption.defaultFollowSystem.rawValue
    @AppStorage("skin_custom_hue") private var customSkinHue = 0.0
    @AppStorage("skin_custom_brightness") private var customSkinBrightness = 1.0
    @AppStorage("skin_custom_swatch_id") private var selectedCustomSkinSwatchID = "000000"
    private let sidebarWidth: CGFloat = 194
    private let themeTransitionAnimation: Animation = .easeInOut(duration: 0.25)

    private enum SkinSourceOption: String, CaseIterable {
        case official
        case vipCustom

        var title: String {
            switch self {
            case .official:
                return "官方"
            case .vipCustom:
                return "自定义换肤"
            }
        }
    }

    private enum APIKeyInputField: Hashable {
        case codex
        case agi
    }

    private enum SkinThemeOption: String, CaseIterable, Identifiable {
        case defaultFollowSystem
        case ivoryWhite
        case coolBlack

        var id: String { rawValue }

        var title: String {
            switch self {
            case .defaultFollowSystem:
                return "默认 - 跟随系统"
            case .ivoryWhite:
                return "霜晨白"
            case .coolBlack:
                return "夜幕黑"
            }
        }
    }

    private var selectedSkinSource: SkinSourceOption {
        SkinSourceOption(rawValue: selectedSkinSourceRawValue) ?? .official
    }

    private var selectedSkinTheme: SkinThemeOption {
        SkinThemeOption(rawValue: selectedSkinThemeRawValue) ?? .defaultFollowSystem
    }

    private struct CustomSkinSwatch: Identifiable {
        let id: String
        let color: Color
        let hue: Double
        let brightness: Double

        init(hex: UInt32, hue: Double, brightness: Double = 0.94) {
            self.id = String(format: "%06X", hex)
            self.color = Color(hex: hex)
            self.hue = hue
            self.brightness = brightness
        }
    }

    private var customSkinSwatches: [CustomSkinSwatch] {
        [
            CustomSkinSwatch(hex: 0x000000, hue: 0.0, brightness: 0.0),
            CustomSkinSwatch(hex: 0xDF5D87, hue: 0.94),
            CustomSkinSwatch(hex: 0xE67896, hue: 0.96),
            CustomSkinSwatch(hex: 0x767BE9, hue: 0.66),
            CustomSkinSwatch(hex: 0x6292DC, hue: 0.60),
            CustomSkinSwatch(hex: 0x69AAD8, hue: 0.56),
            CustomSkinSwatch(hex: 0x66B67A, hue: 0.37),
            CustomSkinSwatch(hex: 0x8BCD4A, hue: 0.25),
            CustomSkinSwatch(hex: 0xD6BA43, hue: 0.13),
            CustomSkinSwatch(hex: 0xEF905F, hue: 0.06),
            CustomSkinSwatch(hex: 0xE87470, hue: 0.01),
            CustomSkinSwatch(hex: 0xE75A50, hue: 0.0),
        ]
    }

    private var customSkinColor: Color {
        Color(
            hue: clampedUnit(customSkinHue),
            saturation: customSkinBrightness <= 0.02 ? 0 : 0.78,
            brightness: max(0, min(1, customSkinBrightness))
        )
    }

    private var isCustomSkinSelected: Bool {
        selectedSkinSource == .vipCustom
    }

    private var themeAccentColor: Color {
        isCustomSkinSelected ? customSkinColor : Color(hex: 0xEF4B4B)
    }

    private var settingsAccentColor: Color {
        isCustomSkinSelected ? themeAccentColor : Color(nsColor: .systemGreen)
    }

    private var selectedControlAccentColor: Color {
        settingsAccentColor
    }

    private var visibleSelectedControlAccentColor: Color {
        if isCustomSkinSelected {
            return visibleThemeAccentColor
        }
        return selectedControlAccentColor
    }

    private var successBadgeColor: Color {
        isCustomSkinSelected ? customSkinColor : Color(nsColor: .systemGreen)
    }

    private var visibleThemeAccentColor: Color {
        if isCustomSkinSelected, customSkinBrightness < 0.28 {
            return Color.white.opacity(0.92)
        }
        return themeAccentColor
    }

    private var selectedSkinSourceFillColor: Color {
        if isCustomSkinSelected, customSkinBrightness < 0.28 {
            return Color.white.opacity(0.10)
        }
        return selectedControlAccentColor.opacity(0.16)
    }

    private var selectedSkinSourceStrokeColor: Color {
        if isCustomSkinSelected, customSkinBrightness < 0.28 {
            return Color.white.opacity(0.24)
        }
        return selectedControlAccentColor.opacity(0.32)
    }

    private var unselectedSkinSourceForegroundColor: Color {
        isCustomSkinSelected ? visibleThemeAccentColor.opacity(0.86) : .primary
    }

    private var unselectedSkinSourceFillColor: Color {
        return Color.white.opacity(isDarkTheme ? 0.06 : 0.62)
    }

    private var unselectedSkinSourceStrokeColor: Color {
        if isCustomSkinSelected, customSkinBrightness < 0.28 {
            return Color.white.opacity(0.14)
        }
        if isCustomSkinSelected {
            return themeAccentColor.opacity(0.22)
        }
        return separatorColor
    }

    private var customSkinBaseBrightness: Double {
        max(0.12, min(0.92, customSkinBrightness))
    }

    private func customThemeColor(saturation: Double, brightnessScale: Double, minimumBrightness: Double) -> Color {
        Color(
            hue: clampedUnit(customSkinHue),
            saturation: customSkinBrightness <= 0.02 ? 0 : saturation,
            brightness: max(minimumBrightness, min(1, customSkinBaseBrightness * brightnessScale))
        )
    }

    private var preferredSkinColorScheme: ColorScheme? {
        if isCustomSkinSelected {
            return .dark
        }

        switch selectedSkinTheme {
        case .defaultFollowSystem:
            return nil
        case .ivoryWhite:
            return .light
        case .coolBlack:
            return .dark
        }
    }

    private var effectiveColorScheme: ColorScheme {
        preferredSkinColorScheme ?? systemColorScheme
    }

    private var isDarkTheme: Bool {
        effectiveColorScheme == .dark
    }

    private var windowBackgroundColor: Color {
        if isCustomSkinSelected {
            return customThemeColor(saturation: 0.30, brightnessScale: 0.13, minimumBrightness: 0.02)
        }
        return isDarkTheme ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF)
    }

    private var sidebarBackgroundColor: Color {
        if isCustomSkinSelected {
            return customThemeColor(saturation: 0.32, brightnessScale: 0.22, minimumBrightness: 0.06)
        }
        return isDarkTheme ? Color(hex: 0x1A1A20) : Color(hex: 0xF0F3F6)
    }

    private var contentBackgroundColor: Color {
        if isCustomSkinSelected {
            return customThemeColor(saturation: 0.25, brightnessScale: 0.16, minimumBrightness: 0.04)
        }
        return isDarkTheme ? Color(hex: 0x131319) : Color(hex: 0xF7F9FC)
    }

    private var separatorColor: Color {
        if isCustomSkinSelected {
            return customSkinColor.opacity(0.24)
        }
        return isDarkTheme ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var selectedTabFillColor: Color {
        if isCustomSkinSelected {
            return customSkinColor.opacity(0.16)
        }
        return successBadgeColor.opacity(isDarkTheme ? 0.18 : 0.12)
    }

    private var selectedTabStrokeColor: Color {
        if isCustomSkinSelected {
            return customSkinColor.opacity(0.34)
        }
        return successBadgeColor.opacity(isDarkTheme ? 0.30 : 0.22)
    }

    private var selectedTabForegroundColor: Color {
        isCustomSkinSelected ? .primary : successBadgeColor
    }

    private var brandLogo: Image {
        let executableDirectory = Bundle.main.bundleURL.deletingLastPathComponent()
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "yls_logo", withExtension: "png"),
            Bundle.main.resourceURL?.appendingPathComponent("yls_logo.png"),
            executableDirectory
                .appendingPathComponent("yls-app_yls-app.bundle")
                .appendingPathComponent("yls_logo.png"),
            executableDirectory
                .appendingPathComponent("yls-app_yls-app.bundle")
                .appendingPathComponent("Contents")
                .appendingPathComponent("Resources")
                .appendingPathComponent("yls_logo.png"),
        ] + Bundle.allBundles.map {
            $0.url(forResource: "yls_logo", withExtension: "png")
        }

        for candidate in candidates {
            if let url = candidate, let nsImage = NSImage(contentsOf: url) {
                return Image(nsImage: nsImage)
            }
        }

        return Image(nsImage: NSApplication.shared.applicationIconImage)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            mainContent
        }
        .background(windowBackgroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, effectiveColorScheme)
        .tint(settingsAccentColor)
        .animation(themeTransitionAnimation, value: selectedSkinThemeRawValue)
        .animation(themeTransitionAnimation, value: selectedSkinSourceRawValue)
        .animation(themeTransitionAnimation, value: customSkinHue)
        .animation(themeTransitionAnimation, value: customSkinBrightness)
    }

    private var sidebarBrandHeader: some View {
        HStack(spacing: 10) {
            brandLogo
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text("伊莉思监控助手")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .background(sidebarBackgroundColor)
    }

    private var mainContentHeader: some View {
        HStack(spacing: 8) {
            Text(topBarStatusText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 10)
            topBarAccountCapsule

            topBarIconButton(systemImage: "arrow.clockwise", action: onRefresh)
            topBarIconButton(systemImage: "gearshape", action: handleSettingsButton)
            topBarIconButton(
                systemImage: "tshirt",
                action: toggleSkinSettingsPage
            )
            topBarIconButton(systemImage: "uiwindow.split.2x1", action: nil)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .center)
        .background(contentBackgroundColor)
    }

    private var topBarStatusText: String {
        if model.currentSource == .codex, model.footerText == "请先设置 API Key" {
            return "请先设置 Codex API Key"
        }
        return model.footerText
    }

    private func topBarIconButton(
        systemImage: String,
        action: (() -> Void)?
    ) -> some View {
        Button(action: { action?() }) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }

    private func toggleSkinSettingsPage() {
        isSkinSettingsPageVisible.toggle()
    }

    private func handleSettingsButton() {
        if isSkinSettingsPageVisible {
            isSkinSettingsPageVisible = false
            if model.panelMode != .settings {
                onTogglePanelMode?()
            }
            return
        }
        onTogglePanelMode?()
    }

    private var topBarAccountCapsule: some View {
        HStack(spacing: 6) {
            Button(action: { onOpenDashboard?() }) {
                HStack(spacing: 5) {
                    Image(systemName: "person")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(model.emailText)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)

            if model.canToggleEmail {
                Button(action: { onToggleEmail?() }) {
                    Image(systemName: model.isEmailVisible ? "eye.slash" : "eye")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(.quaternary, lineWidth: 0.8)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarBrandHeader

            VStack(alignment: .leading, spacing: 8) {
                ForEach(DashboardTab.allCases, id: \.rawValue) { tab in
                    tabButton(tab)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .frame(width: sidebarWidth, alignment: .topLeading)
        .background(sidebarBackgroundColor)
    }

    private func tabButton(_ tab: DashboardTab) -> some View {
        let isSelected = isTabPageVisible && selectedTab == tab
        return Button(action: { selectTab(tab) }) {
            HStack(spacing: 8) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)

                Text(tab.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 6)
            }
            .foregroundStyle(isSelected ? selectedTabForegroundColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? selectedTabFillColor : .clear)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selectedTabStrokeColor, lineWidth: 0.8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var isTabPageVisible: Bool {
        !isSkinSettingsPageVisible && model.panelMode != .settings
    }

    private func selectTab(_ tab: DashboardTab) {
        selectedTab = tab
        if isSkinSettingsPageVisible {
            isSkinSettingsPageVisible = false
        }
        if model.panelMode == .settings {
            onTogglePanelMode?()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            mainContentHeader

            if !isSkinSettingsPageVisible,
               model.panelMode != .settings,
               selectedTab == .codexSwitch,
               isCodexSwitchAddProviderVisible
            {
                codexSwitchAddProviderContent
                    .padding(.leading, 16)
                    .padding(.trailing, 28)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        if isSkinSettingsPageVisible {
                            skinSettingsPage
                        } else if model.panelMode == .settings {
                            settingsPage
                        } else if selectedTab == .usageRecords {
                            usageRecordsContent
                        } else if selectedTab == .codexSwitch {
                            codexSwitchContent
                        } else if selectedTab == .scheduledTasks {
                            scheduledTasksContent
                        } else {
                            usageOverviewContent
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 28)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(contentBackgroundColor)
    }

    private var skinSettingsPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("个性皮肤")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.primary)

                Capsule()
                    .fill(selectedControlAccentColor)
                    .frame(width: 34, height: 4)
            }
            .padding(.top, 4)

            HStack(spacing: 12) {
                ForEach(SkinSourceOption.allCases, id: \.rawValue) { source in
                    skinSourceButton(source)
                }
            }

            if selectedSkinSource == .official {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3),
                    spacing: 16
                ) {
                    ForEach(SkinThemeOption.allCases) { theme in
                        skinThemeCard(theme)
                    }
                }
            } else {
                customSkinSettingsContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func skinSourceButton(_ source: SkinSourceOption) -> some View {
        let isSelected = selectedSkinSource == source
        return Button(action: { selectedSkinSourceRawValue = source.rawValue }) {
            Text(source.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? visibleSelectedControlAccentColor : unselectedSkinSourceForegroundColor)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? selectedSkinSourceFillColor
                                : unselectedSkinSourceFillColor
                        )
                )
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected
                                ? selectedSkinSourceStrokeColor
                                : unselectedSkinSourceStrokeColor,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func skinThemeCard(_ theme: SkinThemeOption) -> some View {
        let isSelected = selectedSkinTheme == theme
        return Button(action: {
            withAnimation(themeTransitionAnimation) {
                selectedSkinThemeRawValue = theme.rawValue
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    skinThemePreview(theme)
                        .frame(height: 148)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    isSelected
                                        ? selectedControlAccentColor.opacity(0.5)
                                        : separatorColor,
                                    lineWidth: isSelected ? 1.2 : 1
                                )
                        }

                    if isSelected {
                        Circle()
                            .fill(selectedControlAccentColor)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(10)
                    }
                }

                Text(theme.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func skinThemePreview(_ theme: SkinThemeOption) -> some View {
        switch theme {
        case .defaultFollowSystem:
            HStack(spacing: 0) {
                Color(hex: 0xF0F3F6)
                Color(hex: 0x1A1A20)
            }
        case .ivoryWhite:
            LinearGradient(
                colors: [
                    Color(hex: 0xF0F3F6),
                    Color(hex: 0xF7F9FC)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .coolBlack:
            LinearGradient(
                colors: [
                    Color(hex: 0x1A1A20),
                    Color(hex: 0x131319)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var customSkinSettingsContent: some View {
        VStack(alignment: .leading, spacing: 34) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(58), spacing: 20), count: 6),
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(customSkinSwatches) { swatch in
                    customSkinSwatchButton(swatch)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("自定义颜色")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white.opacity(0.92))

                HStack(alignment: .center, spacing: 12) {
                    customSkinColorCanvas
                        .frame(width: 78, height: 78)

                    VStack(spacing: 12) {
                        customSkinSlider(
                            value: $customSkinHue,
                            gradientColors: [
                                Color(hex: 0xFF3B30),
                                Color(hex: 0xFF8A1C),
                                Color(hex: 0xFFF23B),
                                Color(hex: 0x80F044),
                                Color(hex: 0x45EBD3),
                                Color(hex: 0x1538FF),
                                Color(hex: 0x9B2DEC),
                                Color(hex: 0xFF2BAA),
                                Color(hex: 0xFF3B30),
                            ],
                            onChanged: { selectedCustomSkinSwatchID = "" }
                        )

                        customSkinSlider(
                            value: $customSkinBrightness,
                            gradientColors: [
                                Color.black,
                                Color(
                                    hue: clampedUnit(customSkinHue),
                                    saturation: 0.78,
                                    brightness: 0.36
                                ),
                                Color(
                                    hue: clampedUnit(customSkinHue),
                                    saturation: 0.78,
                                    brightness: 1.0
                                ),
                            ],
                            onChanged: { selectedCustomSkinSwatchID = "" }
                        )
                    }
                    .frame(minWidth: 280, maxWidth: 560)
                }
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .frame(maxWidth: 720, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x2F3039))
        )
    }

    private func customSkinSwatchButton(_ swatch: CustomSkinSwatch) -> some View {
        let isSelected = selectedCustomSkinSwatchID == swatch.id
        return Button(action: {
            withAnimation(themeTransitionAnimation) {
                selectedCustomSkinSwatchID = swatch.id
                customSkinHue = swatch.hue
                customSkinBrightness = swatch.brightness
            }
        }) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(swatch.color)
                .frame(width: 58, height: 58)
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(
                            isSelected ? Color.white.opacity(0.86) : Color.black.opacity(0.18),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .shadow(color: Color.black.opacity(0.16), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var customSkinColorCanvas: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                AngularGradient(
                    colors: [
                        Color(hex: 0xAFF07F),
                        Color(hex: 0xFFF1A6),
                        Color(hex: 0xF3A3D5),
                        Color(hex: 0xCFA6F0),
                        Color(hex: 0xA5D6FF),
                        Color(hex: 0xA9F2D1),
                        Color(hex: 0xAFF07F),
                    ],
                    center: .center
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.94),
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.0),
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: 68
                        )
                    )
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(customSkinColor)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.86), lineWidth: 1.5)
                    }
                    .padding(8)
            }
    }

    private func customSkinSlider(
        value: Binding<Double>,
        gradientColors: [Color],
        onChanged: (() -> Void)? = nil
    ) -> some View {
        GeometryReader { proxy in
            let knobDiameter: CGFloat = 24
            let trackInset = knobDiameter / 2
            let availableWidth = max(1, proxy.size.width - knobDiameter)
            let knobX = CGFloat(clampedUnit(value.wrappedValue)) * availableWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 14)
                    .padding(.horizontal, trackInset)

                Circle()
                    .fill(Color.white)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: 1)
                    .offset(x: knobX)

                CustomSkinSliderHitLayer(
                    value: value,
                    knobDiameter: knobDiameter,
                    onChanged: onChanged
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
        }
        .frame(height: 26)
    }

    private func clampedUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, min(1, value))
    }

    private var usageOverviewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.statisticsDisplayMode == .dual {
                ForEach(model.sourceGroups, id: \.source.rawValue) { group in
                    SourceSummaryGroupView(
                        model: group,
                        codexDashboard: model.codexDashboard,
                        successBadgeColor: successBadgeColor,
                        useCustomSkin: isCustomSkinSelected,
                        customSkinAccentColor: customSkinColor,
                        onOpenPricing: onOpenPricing
                    ) {
                        onToggleSourceGroup?(group.source)
                    }
                }
            } else {
                if let group = singleModeSourceGroup {
                    SourceSummaryGroupView(
                        model: group,
                        codexDashboard: group.source == .codex ? model.codexDashboard : .empty,
                        successBadgeColor: successBadgeColor,
                        useCustomSkin: isCustomSkinSelected,
                        customSkinAccentColor: customSkinColor,
                        onOpenPricing: onOpenPricing
                    ) {
                        onToggleSourceGroup?(group.source)
                    }
                } else {
                    codexAccordionPanel
                }
            }
        }
    }

    private var codexSwitchContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isCodexSwitchAddProviderVisible {
                codexSwitchAddProviderContent
            } else {
                codexSwitchOverviewContent
            }
        }
        .frame(maxWidth: .infinity, minHeight: 430, alignment: .topLeading)
    }

    private var codexSwitchOverviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Codex Switch")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.primary)

                    Capsule()
                        .fill(selectedControlAccentColor)
                        .frame(width: 34, height: 4)
                }

                Spacer(minLength: 8)

                Button(action: { openCodexSwitchAddProviderPage() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(isDarkTheme ? Color.white.opacity(0.08) : Color.white))
                        .overlay {
                            Circle().stroke(separatorColor, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help("添加供应商")
            }

            if codexSwitchProviders.isEmpty {
                codexSwitchEmptyState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(codexSwitchProviders) { provider in
                        codexSwitchProviderCard(provider)
                    }
                }
            }
        }
    }

    private var codexSwitchAddProviderContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button(action: { isCodexSwitchAddProviderVisible = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(isDarkTheme ? Color.white.opacity(0.08) : Color.white))
                        .overlay {
                            Circle().stroke(separatorColor, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                Text("添加供应商")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("供应商名称")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                            codexSwitchRawInput("例如：Claude 官方", text: $codexSwitchDraftName)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("备注")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                            codexSwitchRawInput("例如：公司专用账号", text: $codexSwitchDraftNotes)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("官网链接")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        codexSwitchRawInput("https://example.com（可选）", text: $codexSwitchDraftWebsite)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("API Key")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        codexSwitchRawInput("只需要填这里，下方 auth.json 会自动填充", text: $codexSwitchDraftAPIKey)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center) {
                            Text("API 请求地址")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)

                            Spacer(minLength: 10)

                            HStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("完整 URL")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Toggle("", isOn: $codexSwitchDraftUseFullURL)
                                        .labelsHidden()
                                        .toggleStyle(.switch)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isDarkTheme ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(separatorColor, lineWidth: 1)
                                }

                                HStack(spacing: 5) {
                                    Image(systemName: "bolt")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("管理与测速")
                                        .font(.system(size: 10.5, weight: .medium))
                                }
                                .foregroundStyle(.secondary)
                            }
                        }

                        codexSwitchRawInput("https://your-api-endpoint.com/v1", text: $codexSwitchDraftEndpoint)

                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(codexSwitchEndpointHintText)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: 0xE8B04E))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: 0x4A3522).opacity(isDarkTheme ? 0.72 : 0.88))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: 0xB86D2B), lineWidth: 1.2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("模型名称")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 10)
                            Button(action: {}) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down")
                                    Text("获取模型列表")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .frame(height: 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isDarkTheme ? Color.white.opacity(0.03) : Color.black.opacity(0.025))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(separatorColor, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        codexSwitchRawInput("", text: $codexSwitchDraftModelName)
                        Text("指定使用的模型，将自动更新到 config.toml 中")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 10)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("auth.json (JSON) *")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        codexSwitchAuthCodeBox(codexSwitchDefaultAuthJSONContent)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("config.toml (TOML)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 10)
                            VStack(alignment: .trailing, spacing: 4) {
                                Toggle(isOn: $codexSwitchDraftWriteGlobalConfig) {
                                    Text("写入通用配置")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .toggleStyle(.switch)

                                Button("编辑通用配置") {}
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(Color(hex: 0x4E9EFF))
                            }
                        }

                        HStack(spacing: 14) {
                            Toggle("", isOn: $codexSwitchDraftOneMillionContext)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                .frame(width: 30)
                            Text("1M 上下文窗口")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("压缩阈值：")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            codexSwitchSmallNumberInput(text: $codexSwitchDraftCompressionThresholdText)
                        }

                        codexSwitchTomlCodeBox(codexSwitchDefaultTOMLContent)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 0) {
                        HStack {
                            HStack(spacing: 10) {
                                Image(systemName: "flask")
                                    .font(.system(size: 14, weight: .medium))
                                Text("模型测试配置")
                                    .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundStyle(.primary)

                                Spacer(minLength: 10)

                                Toggle(isOn: $codexSwitchDraftUseStandaloneTestConfig) {
                                    Text("使用单独配置")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .toggleStyle(.switch)

                                Image(systemName: codexSwitchDraftTestPanelExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    codexSwitchDraftTestPanelExpanded.toggle()
                                }
                            }

                            if codexSwitchDraftTestPanelExpanded {
                                Divider().overlay(separatorColor)

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("为此供应商配置单独的模型测试参数，不启用时使用全局配置。")
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 6)

                                    HStack(alignment: .top, spacing: 20) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("测试模型")
                                                .font(.system(size: 12.5, weight: .semibold))
                                            codexSwitchRawInput("留空使用全局配置", text: $codexSwitchDraftTestModel)
                                                .disabled(!codexSwitchDraftUseStandaloneTestConfig)
                                        }

                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("超时时间（秒）")
                                                .font(.system(size: 12.5, weight: .semibold))
                                            codexSwitchRawInput("", text: $codexSwitchDraftTestTimeoutText)
                                                .disabled(!codexSwitchDraftUseStandaloneTestConfig)
                                        }
                                    }

                                    HStack(alignment: .top, spacing: 20) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("测试提示词")
                                                .font(.system(size: 12.5, weight: .semibold))
                                            codexSwitchRawInput("", text: $codexSwitchDraftTestPrompt)
                                                .disabled(!codexSwitchDraftUseStandaloneTestConfig)
                                        }

                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("降级阈值（毫秒）")
                                                .font(.system(size: 12.5, weight: .semibold))
                                            codexSwitchRawInput("", text: $codexSwitchDraftTestDegradeThresholdText)
                                                .disabled(!codexSwitchDraftUseStandaloneTestConfig)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("最大重试次数")
                                            .font(.system(size: 12.5, weight: .semibold))
                                        codexSwitchRawInput("", text: $codexSwitchDraftTestMaxRetriesText)
                                            .disabled(!codexSwitchDraftUseStandaloneTestConfig)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .opacity(codexSwitchDraftUseStandaloneTestConfig ? 1 : 0.45)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isDarkTheme ? Color.white.opacity(0.02) : Color.black.opacity(0.01))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(separatorColor, lineWidth: 1)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            HStack(spacing: 10) {
                Spacer(minLength: 8)

                Button("取消") {
                    isCodexSwitchAddProviderVisible = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 72, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isDarkTheme ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(separatorColor, lineWidth: 0.8)
                }

                Button("保存") {
                    saveCodexSwitchProvider()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selectedControlAccentColor)
                )
                .disabled(codexSwitchDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(codexSwitchDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            .padding(.top, 4)
            .padding(.horizontal, 12)
        }
    }

    private func codexSwitchRawInput(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text(placeholder)
                .foregroundColor(.secondary.opacity(0.9))
        )
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.primary)
        .textFieldStyle(.plain)
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDarkTheme ? Color(hex: 0x1A1B23) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(separatorColor, lineWidth: 1.1)
        }
    }

    private var codexSwitchDefaultTOMLContent: String {
        """
model_provider = "custom"
model = "\(codexSwitchDraftModelName)"
model_reasoning_effort = "high"
disable_response_storage = true
approval_policy = "on-request"
sandbox_mode = "workspace-write"
network_access = "enabled"
personality = "pragmatic"
service_tier = "fast"
env_key = "OPENAI_API_KEY"
"""
    }

    private var codexSwitchDefaultAuthJSONContent: String {
        """
{
  "OPENAI_API_KEY": "\(codexSwitchDraftAPIKey)"
}
"""
    }

    private var codexSwitchEndpointHintText: String {
        if codexSwitchDraftUseFullURL {
            return "请填写完整请求 URL，并且必须开启路由后使用；路由将直接使用此 URL，不拼接路径"
        }
        return "填写兼容 OpenAI Response 格式的服务端点地址"
    }

    private func codexSwitchAuthCodeBox(_ content: String) -> some View {
        codexSwitchRichCodePanel(
            language: "JSON",
            content: content,
            languageKey: "json",
        )
    }

    private func codexSwitchTomlCodeBox(_ content: String) -> some View {
        codexSwitchRichCodePanel(
            language: "TOML",
            content: content,
            languageKey: "toml",
        )
    }

    private func codexSwitchRichCodePanel(
        language: String,
        content: String,
        languageKey: String,
    ) -> some View {
        let inputBackground = isDarkTheme ? Color(hex: 0x1A1B23) : Color.white
        let panelBackground = inputBackground
        let codeBackground = inputBackground
        let textColor = Color(hex: isDarkTheme ? 0xD7DEE8 : 0x1F2937)
        let displayContent = content.trimmingCharacters(in: .newlines)
        let lines = displayContent.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let markdownCode = "```\(languageKey)\n\(displayContent)\n```"

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    Text(language)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(
                            Capsule()
                                .fill(isDarkTheme ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                        )
                        .overlay {
                            Capsule()
                                .stroke(separatorColor, lineWidth: 0.8)
                        }

                    Button(action: { NSPasteboard.general.setString(displayContent, forType: .string) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                            Text("复制")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(
                            Capsule()
                                .fill(isDarkTheme ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                        .overlay {
                            Capsule()
                                .stroke(separatorColor, lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11, weight: .semibold))
                            Text("格式化")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(
                            Capsule()
                                .fill(isDarkTheme ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                        .overlay {
                            Capsule()
                                .stroke(separatorColor, lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 46, alignment: .center)
            .padding(.horizontal, 16)

            Divider().overlay(separatorColor)

            ScrollView(.horizontal, showsIndicators: true) {
                Markdown(markdownCode)
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(16.5)
                        ForegroundColor(textColor)
                    }
                    .markdownBlockStyle(\.codeBlock) { configuration in
                        HStack(alignment: .top, spacing: 0) {
                            VStack(alignment: .trailing, spacing: 0) {
                                ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                                    Text("\(index + 1)")
                                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color.secondary.opacity(0.6))
                                        .frame(height: 20)
                                }
                            }
                            .padding(.trailing, 12)
                            .padding(.vertical, 14)
                            .padding(.leading, 14)
                            .background(Color.clear)

                            configuration.label
                                .padding(.vertical, 14)
                                .padding(.trailing, 16)
                                .background(Color.clear)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(codeBackground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(panelBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
        .clipped()
    }

    private func codexSwitchSmallNumberInput(text: Binding<String>) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .frame(width: 220, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDarkTheme ? Color(hex: 0x1A1B23) : Color.white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(separatorColor, lineWidth: 1)
            }
    }

    private var codexSwitchEmptyState: some View {
        VStack(alignment: .center, spacing: 14) {
            Spacer(minLength: 56)

            Text("暂无供应商")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.primary)

            Text("点击右上角 + 添加第一个供应商")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 96)
        }
        .frame(maxWidth: .infinity, minHeight: 330)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.06) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
    }

    private func codexSwitchProviderCard(_ provider: CodexSwitchProviderItem) -> some View {
        let scope = CodexSwitchProviderItem.Scope(rawValue: provider.scope) ?? .appSpecific
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(provider.name.isEmpty ? "未命名供应商" : provider.name)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(scope.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(selectedControlAccentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(selectedControlAccentColor.opacity(isDarkTheme ? 0.24 : 0.12))
                    )

                Spacer(minLength: 8)
            }

            Text(provider.endpoint.isEmpty ? "未配置接口地址" : provider.endpoint)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.06) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
    }

    private func openCodexSwitchAddProviderPage() {
        codexSwitchDraftScopeRawValue = CodexSwitchProviderItem.Scope.appSpecific.rawValue
        codexSwitchDraftPreset = "OpenAI"
        codexSwitchDraftName = ""
        codexSwitchDraftEndpoint = ""
        codexSwitchDraftAPIKey = ""
        codexSwitchDraftWebsite = ""
        codexSwitchDraftNotes = ""
        codexSwitchDraftUseFullURL = false
        codexSwitchDraftModelName = "gpt-5.4"
        codexSwitchDraftWriteGlobalConfig = true
        codexSwitchDraftCompressionThresholdText = "900000"
        codexSwitchDraftOneMillionContext = false
        codexSwitchDraftUseStandaloneTestConfig = false
        codexSwitchDraftTestPanelExpanded = false
        codexSwitchDraftTestModel = ""
        codexSwitchDraftTestTimeoutText = "45"
        codexSwitchDraftTestDegradeThresholdText = "6000"
        codexSwitchDraftTestPrompt = "Who are you?"
        codexSwitchDraftTestMaxRetriesText = "2"
        isCodexSwitchAddProviderVisible = true
    }

    private func saveCodexSwitchProvider() {
        let rawEndpoint = codexSwitchDraftEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEndpoint = resolveCodexSwitchEndpoint(
            rawEndpoint: rawEndpoint,
            useFullURL: codexSwitchDraftUseFullURL
        )
        let provider = CodexSwitchProviderItem(
            id: UUID().uuidString,
            scope: CodexSwitchProviderItem.normalizedScope(codexSwitchDraftScopeRawValue),
            preset: codexSwitchDraftPreset.trimmingCharacters(in: .whitespacesAndNewlines),
            name: codexSwitchDraftName.trimmingCharacters(in: .whitespacesAndNewlines),
            endpoint: resolvedEndpoint,
            useFullURL: codexSwitchDraftUseFullURL,
            apiKey: codexSwitchDraftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            website: codexSwitchDraftWebsite.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: codexSwitchDraftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        codexSwitchProviders.append(provider)
        CodexSwitchProviderItem.saveAll(codexSwitchProviders)
        isCodexSwitchAddProviderVisible = false
    }

    private func resolveCodexSwitchEndpoint(rawEndpoint: String, useFullURL: Bool) -> String {
        guard !rawEndpoint.isEmpty else { return rawEndpoint }
        if useFullURL {
            return rawEndpoint
        }

        let trimmedPath = rawEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.lowercased().hasSuffix("responses") {
            return rawEndpoint
        }

        if rawEndpoint.hasSuffix("/") {
            return rawEndpoint + "responses"
        }
        return rawEndpoint + "/responses"
    }

    private var scheduledTasksContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            if isScheduledTaskEditorVisible {
                scheduledTaskEditorPage
            } else if !scheduledTasks.isEmpty {
                scheduledTasksSegmentHeader
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(scheduledTasks) { task in
                        scheduledTaskCard(task)
                    }
                }
            } else {
                scheduledTasksEmptyState
            }
        }
        .frame(maxWidth: .infinity, minHeight: 430, alignment: .topLeading)
    }

    private var scheduledTasksSegmentHeader: some View {
        HStack(spacing: 12) {
            Text("任务列表")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isDarkTheme ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                )

            Spacer(minLength: 8)

            Button(action: {
                openNewScheduledTaskEditor()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(isDarkTheme ? Color.white.opacity(0.08) : Color.white))
                    .overlay {
                        Circle().stroke(separatorColor, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .help("新增定时任务")
        }
    }

    private var scheduledTaskEditorPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button(action: {
                    isScheduledTaskEditorVisible = false
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(isDarkTheme ? Color.white.opacity(0.08) : Color.white))
                        .overlay {
                            Circle().stroke(separatorColor, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                Text(isEditingScheduledTask ? "编辑定时任务" : "新建定时任务")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)
            }

            VStack(alignment: .leading, spacing: 16) {
                scheduledTaskTextFieldRow(
                    title: "任务标题",
                    systemImage: "pencil",
                    placeholder: "请输入任务标题",
                    text: $scheduledTaskDraftTitle
                )

                scheduledTaskDescriptionRow

                scheduledTaskIconEditorRow

                scheduledTaskConfirmActionEditorRow

                scheduledTaskActionButtonsEditorRow

                scheduledTaskTimeEditorRow

                HStack(spacing: 10) {
                    Spacer(minLength: 8)

                    Button("取消") {
                        isScheduledTaskEditorVisible = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 72, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isDarkTheme ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(separatorColor, lineWidth: 0.8)
                    }

                    Button("保存") {
                        saveScheduledTaskFromEditor()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(scheduledTaskAccentColor)
                    )
                    .disabled(scheduledTaskDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(scheduledTaskDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(scheduledTaskCardFillColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(scheduledTaskCardStrokeColor, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(isDarkTheme ? 0.18 : 0.05), radius: 8, x: 0, y: 3)
        }
    }

    private func scheduledTaskTextFieldRow(
        title: String,
        systemImage: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 12) {
            scheduledTaskFormLabel(title: title, systemImage: systemImage)

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5, weight: .semibold))
        }
    }

    private var scheduledTaskDescriptionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            scheduledTaskFormLabel(title: "任务描述", systemImage: "text.alignleft")

            TextEditor(text: $scheduledTaskDraftDescription)
                .font(.system(size: 12.5, weight: .semibold))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(minHeight: 78)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isDarkTheme ? Color.white.opacity(0.06) : Color.black.opacity(0.035))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(separatorColor, lineWidth: 1)
                }
        }
    }

    private var scheduledTaskIconEditorRow: some View {
        HStack(spacing: 12) {
            scheduledTaskFormLabel(title: "弹窗图标", systemImage: "photo")

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isDarkTheme ? Color.white.opacity(0.06) : Color.black.opacity(0.035))

                if let image = scheduledTaskDraftIconImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(7)
                } else {
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(scheduledTaskAccentColor)
                }
            }
            .frame(width: 52, height: 52)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(separatorColor, lineWidth: 1)
            }

            Button("上传") {
                selectScheduledTaskIcon()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 64, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(scheduledTaskAccentColor)
            )

            Button("移除") {
                scheduledTaskDraftIconImageDataBase64 = nil
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(.primary)
            .frame(width: 64, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDarkTheme ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(separatorColor, lineWidth: 0.8)
            }
            .disabled(scheduledTaskDraftIconImageDataBase64 == nil)
            .opacity(scheduledTaskDraftIconImageDataBase64 == nil ? 0.45 : 1)

            Spacer(minLength: 8)
        }
    }

    private var scheduledTaskActionButtonsEditorRow: some View {
        HStack(spacing: 12) {
            scheduledTaskFormLabel(title: "弹窗按钮", systemImage: "rectangle.2.swap")

            TextField("", text: $scheduledTaskDraftCancelButtonTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5, weight: .semibold))

            TextField("", text: $scheduledTaskDraftConfirmButtonTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5, weight: .semibold))
        }
    }

    private var scheduledTaskConfirmActionEditorRow: some View {
        HStack(spacing: 12) {
            scheduledTaskFormLabel(title: "确认动作", systemImage: "checkmark.circle")

            Picker("", selection: $scheduledTaskDraftActionRawValue) {
                ForEach(ScheduledTaskAction.allCases, id: \.rawValue) { action in
                    Label(action.title, systemImage: action.systemImage)
                        .tag(action.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)

            Spacer(minLength: 8)
        }
    }

    private var scheduledTaskDraftAction: ScheduledTaskAction {
        ScheduledTaskAction(rawValue: scheduledTaskDraftActionRawValue) ?? .none
    }

    private var scheduledTaskDraftIconImage: NSImage? {
        scheduledTaskIconImage(from: scheduledTaskDraftIconImageDataBase64)
    }

    private var scheduledTaskTimeEditorRow: some View {
        HStack(spacing: 12) {
            scheduledTaskFormLabel(title: "执行时间", systemImage: "clock")

            Spacer(minLength: 8)

            Picker("", selection: $scheduledTaskDraftRepeatKindRawValue) {
                ForEach(ScheduledTaskRepeatKind.allCases, id: \.rawValue) { repeatKind in
                    Text(repeatKind.title).tag(repeatKind.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
            .onChange(of: scheduledTaskDraftRepeatKindRawValue) { newValue in
                let repeatKind = ScheduledTaskRepeatKind(rawValue: newValue) ?? .daily
                scheduledTaskDraftRepeatDayText = sanitizedRepeatDayText(
                    scheduledTaskDraftRepeatDayText,
                    repeatKind: repeatKind
                )
            }

            if scheduledTaskDraftRepeatKind != .daily {
                scheduledTaskRepeatDayInput(
                    text: $scheduledTaskDraftRepeatDayText,
                    repeatKind: scheduledTaskDraftRepeatKind
                )
                .onChange(of: scheduledTaskDraftRepeatDayText) { newValue in
                    scheduledTaskDraftRepeatDayText = sanitizedRepeatDayText(
                        newValue,
                        repeatKind: scheduledTaskDraftRepeatKind
                    )
                }
            }

            scheduledTaskTimeInput(
                text: $scheduledTaskDraftHourText,
                suffix: "时"
            )
            .onChange(of: scheduledTaskDraftHourText) { newValue in
                scheduledTaskDraftHourText = sanitizedTimeText(newValue, maxValue: 23)
            }

            scheduledTaskTimeInput(
                text: $scheduledTaskDraftMinuteText,
                suffix: "分"
            )
            .onChange(of: scheduledTaskDraftMinuteText) { newValue in
                scheduledTaskDraftMinuteText = sanitizedTimeText(newValue, maxValue: 59)
            }
        }
    }

    private func scheduledTaskRepeatDayInput(
        text: Binding<String>,
        repeatKind: ScheduledTaskRepeatKind
    ) -> some View {
        HStack(spacing: 5) {
            if repeatKind == .weekly {
                Text("周")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            TextField(repeatKind == .weekly ? "1" : "1", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 46)

            if repeatKind == .monthly {
                Text("号")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scheduledTaskTimeInput(text: Binding<String>, suffix: String) -> some View {
        HStack(spacing: 5) {
            TextField("00", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 46)

            Text(suffix)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    private func scheduledTaskFormLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(scheduledTaskAccentColor)
                .frame(width: 22, height: 22)
                .background(Circle().fill(scheduledTaskAccentColor.opacity(isDarkTheme ? 0.18 : 0.10)))

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 76, alignment: .leading)
        }
    }

    private func scheduledTaskCard(_ task: ScheduledTaskItem) -> some View {
        let accentColor = scheduledTaskAccentColor
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(isDarkTheme ? 0.18 : 0.10))
                    if let iconImage = scheduledTaskIconImage(from: task.iconImageDataBase64) {
                        Image(nsImage: iconImage)
                            .resizable()
                            .scaledToFit()
                            .padding(13)
                    } else {
                        Image(systemName: scheduledTaskReminderType(for: task).systemImage)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(accentColor)
                    }
                    if scheduledTaskAction(for: task) == .shutdown {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color(hex: 0xFF4D55)))
                            .offset(x: 24, y: 24)
                    }
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(scheduledTaskDisplayTitle(for: task)) \(scheduledTaskTimeText(for: task))")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(scheduledTaskRepeatTimeText(for: task))：\(scheduledTaskDisplayDescription(for: task))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Toggle("", isOn: bindingForScheduledTaskEnabled(task.id))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(settingsAccentColor)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Divider().overlay(separatorColor)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Spacer(minLength: 0)

                Button(action: {
                    presentedScheduledTaskMenuID = task.id
                    isScheduledTaskMenuPresented.toggle()
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(
                    isPresented: Binding(
                        get: { isScheduledTaskMenuPresented && presentedScheduledTaskMenuID == task.id },
                        set: { isPresented in
                            isScheduledTaskMenuPresented = isPresented
                            if !isPresented {
                                presentedScheduledTaskMenuID = nil
                            }
                        }
                    ),
                    arrowEdge: .bottom
                ) {
                    scheduledTaskActionPopover(task)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(scheduledTaskCardFillColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(scheduledTaskCardStrokeColor, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(isDarkTheme ? 0.18 : 0.05), radius: 8, x: 0, y: 3)
    }

    private func scheduledTaskActionPopover(_ task: ScheduledTaskItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                isScheduledTaskMenuPresented = false
                updateScheduledTask(task.id) { item in
                    item.enabled = true
                    item.reminderType = ScheduledTaskReminderType.popup.rawValue
                }
                NotificationCenter.default.post(name: .scheduledTaskReminderRequested, object: task.id)
            }) {
                Label("立即执行", systemImage: "play")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 132, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: {
                isScheduledTaskMenuPresented = false
                openEditScheduledTaskEditor(task)
            }) {
                Label("编辑", systemImage: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 132, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: {
                isScheduledTaskMenuPresented = false
                removeScheduledTask(task.id)
                NotificationCenter.default.post(name: .scheduledTaskReminderConfigurationChanged, object: nil)
            }) {
                Label("移除", systemImage: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFF4D55))
                    .frame(width: 132, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDarkTheme ? Color(hex: 0x202026) : Color.white)
        )
    }

    private var scheduledTasksEmptyState: some View {
        VStack(alignment: .center, spacing: 18) {
            Spacer(minLength: 44)

            Text("⏰")
                .font(.system(size: 62))

            Text("点击下方按钮，开启你的第一个任务吧")
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Button(action: {
                openNewScheduledTaskEditor()
            }) {
                Text("新建定时任务")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(scheduledTaskAccentColor))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity, minHeight: 350, alignment: .center)
    }

    private func scheduledTaskTimeText(for task: ScheduledTaskItem) -> String {
        String(format: "%02d:%02d", task.hour, task.minute)
    }

    private func scheduledTaskChineseTimeText(for task: ScheduledTaskItem) -> String {
        let period = task.hour < 12 ? "上午" : "下午"
        let displayHour = task.hour <= 12 ? task.hour : task.hour - 12
        return String(format: "%@%d:%02d", period, max(1, displayHour), task.minute)
    }

    private func scheduledTaskRepeatKind(for task: ScheduledTaskItem) -> ScheduledTaskRepeatKind {
        ScheduledTaskRepeatKind(rawValue: task.repeatKind) ?? .daily
    }

    private var scheduledTaskDraftRepeatKind: ScheduledTaskRepeatKind {
        ScheduledTaskRepeatKind(rawValue: scheduledTaskDraftRepeatKindRawValue) ?? .daily
    }

    private func scheduledTaskReminderType(for task: ScheduledTaskItem) -> ScheduledTaskReminderType {
        ScheduledTaskReminderType(rawValue: task.reminderType) ?? .popup
    }

    private func scheduledTaskAction(for task: ScheduledTaskItem) -> ScheduledTaskAction {
        ScheduledTaskAction(rawValue: task.action) ?? .none
    }

    private func scheduledTaskRepeatTimeText(for task: ScheduledTaskItem) -> String {
        switch scheduledTaskRepeatKind(for: task) {
        case .daily:
            return "每天\(scheduledTaskChineseTimeText(for: task))"
        case .weekly:
            return "每周\(scheduledTaskWeekdayText(task.repeatDay))\(scheduledTaskChineseTimeText(for: task))"
        case .monthly:
            return "每月\(task.repeatDay)号\(scheduledTaskChineseTimeText(for: task))"
        }
    }

    private func scheduledTaskWeekdayText(_ value: Int) -> String {
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

    private func scheduledTaskDisplayTitle(for task: ScheduledTaskItem) -> String {
        let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名定时任务" : trimmed
    }

    private func scheduledTaskDisplayDescription(for task: ScheduledTaskItem) -> String {
        let trimmed = task.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "无任务描述。" : trimmed
    }

    private func openNewScheduledTaskEditor() {
        isEditingScheduledTask = false
        editingScheduledTaskID = nil
        scheduledTaskDraftTitle = ""
        scheduledTaskDraftDescription = ""
        scheduledTaskDraftActionRawValue = ScheduledTaskAction.none.rawValue
        scheduledTaskDraftRepeatKindRawValue = ScheduledTaskRepeatKind.daily.rawValue
        scheduledTaskDraftRepeatDayText = "1"
        scheduledTaskDraftHourText = ""
        scheduledTaskDraftMinuteText = ""
        scheduledTaskDraftCancelButtonTitle = ""
        scheduledTaskDraftConfirmButtonTitle = ""
        isScheduledTaskEditorVisible = true
    }

    private func openEditScheduledTaskEditor(_ task: ScheduledTaskItem) {
        isEditingScheduledTask = true
        editingScheduledTaskID = task.id
        scheduledTaskDraftTitle = task.title
        scheduledTaskDraftDescription = task.description
        scheduledTaskDraftActionRawValue = scheduledTaskAction(for: task).rawValue
        scheduledTaskDraftRepeatKindRawValue = scheduledTaskRepeatKind(for: task).rawValue
        scheduledTaskDraftRepeatDayText = "\(task.repeatDay)"
        scheduledTaskDraftHourText = String(format: "%02d", task.hour)
        scheduledTaskDraftMinuteText = String(format: "%02d", task.minute)
        scheduledTaskDraftCancelButtonTitle = task.cancelButtonTitle
        scheduledTaskDraftConfirmButtonTitle = task.confirmButtonTitle
        isScheduledTaskEditorVisible = true
    }

    private func saveScheduledTaskFromEditor() {
        let normalizedTask = ScheduledTaskItem(
            id: editingScheduledTaskID ?? UUID().uuidString,
            enabled: true,
            title: scheduledTaskDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            description: scheduledTaskDraftDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            reminderType: ScheduledTaskReminderType.popup.rawValue,
            action: scheduledTaskDraftAction.rawValue,
            repeatKind: scheduledTaskDraftRepeatKind.rawValue,
            repeatDay: clampedRepeatDayValue(
                scheduledTaskDraftRepeatDayText,
                repeatKind: scheduledTaskDraftRepeatKind
            ),
            hour: clampedTimeValue(scheduledTaskDraftHourText, maxValue: 23),
            minute: clampedTimeValue(scheduledTaskDraftMinuteText, maxValue: 59),
            cancelButtonTitle: normalizedScheduledTaskButtonTitle(
                scheduledTaskDraftCancelButtonTitle,
                fallback: "再卷一会儿"
            ),
            confirmButtonTitle: normalizedScheduledTaskButtonTitle(
                scheduledTaskDraftConfirmButtonTitle,
                fallback: "准点下班"
            ),
            iconImageDataBase64: scheduledTaskDraftIconImageDataBase64
        )

        if let editingScheduledTaskID,
           let index = scheduledTasks.firstIndex(where: { $0.id == editingScheduledTaskID })
        {
            scheduledTasks[index] = normalizedTask
        } else {
            scheduledTasks.append(normalizedTask)
        }

        persistScheduledTasks()
        editingScheduledTaskID = nil
        isEditingScheduledTask = false
        isScheduledTaskEditorVisible = false
        NotificationCenter.default.post(name: .scheduledTaskReminderConfigurationChanged, object: nil)
    }

    private func normalizedScheduledTaskButtonTitle(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func selectScheduledTaskIcon() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK,
              let url = panel.url,
              let data = try? Data(contentsOf: url)
        else {
            return
        }

        scheduledTaskDraftIconImageDataBase64 = data.base64EncodedString()
    }

    private func scheduledTaskIconImage(from base64: String?) -> NSImage? {
        guard let base64,
              let data = Data(base64Encoded: base64)
        else {
            return nil
        }

        return NSImage(data: data)
    }

    private func bindingForScheduledTaskEnabled(_ id: String) -> Binding<Bool> {
        Binding(
            get: {
                scheduledTasks.first(where: { $0.id == id })?.enabled ?? false
            },
            set: { newValue in
                updateScheduledTask(id) { item in
                    item.enabled = newValue
                }
                NotificationCenter.default.post(name: .scheduledTaskReminderConfigurationChanged, object: nil)
            }
        )
    }

    private func updateScheduledTask(_ id: String, mutate: (inout ScheduledTaskItem) -> Void) {
        guard let index = scheduledTasks.firstIndex(where: { $0.id == id }) else { return }
        mutate(&scheduledTasks[index])
        persistScheduledTasks()
    }

    private func removeScheduledTask(_ id: String) {
        scheduledTasks.removeAll { $0.id == id }
        persistScheduledTasks()
    }

    private func persistScheduledTasks() {
        ScheduledTaskItem.saveAll(scheduledTasks)
        scheduledTaskConfigured = !scheduledTasks.isEmpty
    }

    private func sanitizedTimeText(_ value: String, maxValue: Int) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        let limited = String(digits.prefix(2))
        guard let parsed = Int(limited) else { return limited }
        return "\(min(maxValue, parsed))"
    }

    private func sanitizedRepeatDayText(_ value: String, repeatKind: ScheduledTaskRepeatKind) -> String {
        guard repeatKind != .daily else { return "1" }
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        let limited = String(digits.prefix(2))
        guard let parsed = Int(limited) else { return limited }
        let maxValue = repeatKind == .weekly ? 7 : 31
        return "\(max(1, min(maxValue, parsed)))"
    }

    private func clampedTimeValue(_ value: String, maxValue: Int) -> Int {
        guard let parsed = Int(value) else { return 0 }
        return max(0, min(maxValue, parsed))
    }

    private func clampedRepeatDayValue(_ value: String, repeatKind: ScheduledTaskRepeatKind) -> Int {
        guard repeatKind != .daily else { return 1 }
        let maxValue = repeatKind == .weekly ? 7 : 31
        guard let parsed = Int(value) else { return 1 }
        return max(1, min(maxValue, parsed))
    }

    private var scheduledTaskAccentColor: Color {
        isCustomSkinSelected ? visibleThemeAccentColor : successBadgeColor
    }

    private var scheduledTaskCardFillColor: Color {
        if isCustomSkinSelected {
            return customSkinColor.opacity(customSkinBrightness < 0.28 ? 0.10 : 0.13)
        }
        return isDarkTheme ? Color.white.opacity(0.06) : Color.white
    }

    private var scheduledTaskCardStrokeColor: Color {
        if isCustomSkinSelected {
            return customSkinColor.opacity(0.34)
        }
        return separatorColor
    }

    private var singleModeSourceGroup: SourceSummaryGroupViewModel? {
        if let matched = model.sourceGroups.first(where: { $0.source.chipTitle == model.currentSourceTitle }) {
            return matched
        }
        return model.sourceGroups.first(where: { $0.source == .codex }) ?? model.sourceGroups.first
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            inlineSettingCard(title: "统计模式", systemImage: "square.split.2x1") {
                Picker("", selection: Binding(
                    get: { model.statisticsDisplayMode },
                    set: { onSelectStatisticsMode?($0) }
                )) {
                    ForEach(StatisticsDisplayMode.allCases, id: \.rawValue) { mode in
                        Text(mode.fullTitle).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 122)
            }

            inlineSettingCard(title: "单显套餐源", systemImage: "square.stack.3d.up") {
                Picker("", selection: Binding(
                    get: { model.currentSource },
                    set: { onSelectSource?($0) }
                )) {
                    ForEach(PackageSource.allCases, id: \.rawValue) { source in
                        Text(source.title).tag(source)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 122)
            }

            launchAtLoginSettingCard

            statusBarSettingsPanel

            keySettingCard(
                title: PackageSource.codex.keyButtonTitle,
                statusText: model.codexAPIKeyStatusText,
                maskedText: model.codexAPIKeyMaskedText,
                placeholder: "粘贴 Codex API Key",
                field: .codex,
                text: $codexAPIKeyDraft,
                onClear: { clearAPIKey(for: .codex) }
            ) {
                saveAPIKey(for: .codex, draft: codexAPIKeyDraft)
            }

            keySettingCard(
                title: PackageSource.agi.keyButtonTitle,
                statusText: model.agiAPIKeyStatusText,
                maskedText: model.agiAPIKeyMaskedText,
                placeholder: "粘贴 AGI API Key",
                field: .agi,
                text: $agiAPIKeyDraft,
                onClear: { clearAPIKey(for: .agi) }
            ) {
                saveAPIKey(for: .agi, draft: agiAPIKeyDraft)
            }

            inlineSettingCard(title: "轮询间隔", systemImage: "timer") {
                Picker("", selection: $intervalSecondsDraft) {
                    ForEach([3, 5, 10, 15, 30, 60], id: \.self) { value in
                        Text("\(value) 秒").tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 96)
                .onChange(of: intervalSecondsDraft) { newValue in
                    onSetInterval?(Double(newValue))
                }
            }

            mcpSettingCard

        }
        .tint(settingsAccentColor)
        .onAppear {
            syncSettingsDraftFromModel()
        }
    }

    private var launchAtLoginSettingCard: some View {
        let isSupported = model.launchAtLoginSupported
        let reasonText = model.launchAtLoginUnavailableReason ?? ""
        let showReason = !isSupported && !reasonText.isEmpty
        let cardFill: Color = isSupported
            ? (isDarkTheme ? Color.white.opacity(0.05) : Color.white)
            : Color.orange.opacity(0.06)
        let cardStroke: Color = isSupported ? separatorColor : Color.orange.opacity(0.38)
        let iconColor: Color = isSupported ? .secondary : .orange

        return VStack(alignment: .leading, spacing: showReason ? 7 : 0) {
            HStack(spacing: 10) {
                Image(systemName: model.launchAtLoginEnabled ? "power.circle.fill" : "power.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.thinMaterial))

                Text("开机自启")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSupported ? .primary : .secondary)

                if !isSupported {
                    Text("不可用")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.14))
                        .overlay {
                            Capsule().stroke(Color.orange.opacity(0.36), lineWidth: 0.8)
                        }
                        .clipShape(Capsule())
                }

                Spacer(minLength: 8)

                Toggle(
                    "",
                    isOn: Binding(
                        get: { model.launchAtLoginEnabled && isSupported },
                        set: { onToggleLaunchAtLogin?($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!isSupported)
            }

            if showReason {
                Text(reasonText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(cardFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        }
        .help(showReason ? reasonText : "支持开启开机自启")
    }

    private func inlineSettingCard<Control: View>(
        title: String,
        systemImage: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.thinMaterial))

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            control()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.05) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
    }

    private func keySettingCard(
        title: String,
        statusText: String,
        maskedText: String,
        placeholder: String,
        field: APIKeyInputField,
        text: Binding<String>,
        onClear: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) -> some View {
        let isConfigured = statusText == "已配置"
        let displayText = Binding<String>(
            get: {
                let draft = text.wrappedValue
                if isConfigured,
                   focusedAPIKeyField != field,
                   draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !maskedText.isEmpty {
                    return maskedText
                }
                return draft
            },
            set: { newValue in
                text.wrappedValue = newValue
            }
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.thinMaterial))

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Text(statusText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isConfigured ? successBadgeColor : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isConfigured ? successBadgeColor.opacity(0.12) : Color.white.opacity(0.10))
                    .overlay {
                        if isConfigured {
                            Capsule().stroke(successBadgeColor.opacity(0.22), lineWidth: 0.8)
                        }
                    }
                    .clipShape(Capsule())

                Spacer(minLength: 8)

                if isConfigured {
                    Button("清空") {
                        onClear()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                SecureField(placeholder, text: displayText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .medium))
                    .focused($focusedAPIKeyField, equals: field)
                    .onTapGesture {
                        if isConfigured, text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            text.wrappedValue = ""
                        }
                    }
                    .onSubmit(onSave)

                Button("保存") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.05) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
    }

    private var mcpSettingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.thinMaterial))

                Text("MCP 服务")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Toggle("", isOn: $mcpEnabledDraft)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            HStack(spacing: 8) {
                Text("端口")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("8765", text: $mcpPortDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 92)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                Button("应用") {
                    applyMCPSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer(minLength: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.05) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
        .onChange(of: mcpEnabledDraft) { _ in
            applyMCPSettings()
        }
    }

    private func saveAPIKey(for source: PackageSource, draft: String) {
        let normalized = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        onSetAPIKey?(source, normalized)
        if source == .codex {
            codexAPIKeyDraft = ""
        } else {
            agiAPIKeyDraft = ""
        }
    }

    private func clearAPIKey(for source: PackageSource) {
        onSetAPIKey?(source, "")
        if source == .codex {
            codexAPIKeyDraft = ""
        } else {
            agiAPIKeyDraft = ""
        }
    }

    private func applyMCPSettings() {
        let port = UInt16(mcpPortDraft.trimmingCharacters(in: .whitespacesAndNewlines)) ?? model.mcpPort
        onConfigureMCP?(mcpEnabledDraft, max(UInt16(1), port))
    }

    private func syncSettingsDraftFromModel() {
        intervalSecondsDraft = max(1, Int(model.pollIntervalSeconds.rounded()))
        mcpEnabledDraft = model.mcpEnabled
        mcpPortDraft = "\(model.mcpPort)"
        statusBarAutoAdaptDraft = model.statusBarForegroundMode == .autoAdapt
        statusBarManualColorDraft = colorFromHex(model.statusBarManualColorHex) ?? .white
    }

    private var statusBarSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isStatusBarSettingsExpanded.toggle() }) {
                HStack(spacing: 10) {
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.thinMaterial))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("状态栏")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text("\(model.displayStyle.chipTitle) · \(model.statusBarColorText)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isStatusBarSettingsExpanded ? 0 : -90))
                        .frame(width: 18, height: 18)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(isDarkTheme ? Color.white.opacity(0.05) : Color.white)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(separatorColor, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if isStatusBarSettingsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("文本颜色")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)

                        Text(model.statusBarColorText)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Toggle("自动适配状态栏背景", isOn: $statusBarAutoAdaptDraft)
                        .font(.system(size: 11.5, weight: .semibold))
                        .onChange(of: statusBarAutoAdaptDraft) { _ in
                            applyStatusBarColorSettings()
                        }

                    HStack(spacing: 8) {
                        Text("手动颜色")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ColorPicker("", selection: $statusBarManualColorDraft, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(statusBarAutoAdaptDraft)
                            .onChange(of: statusBarManualColorDraft) { _ in
                                applyStatusBarColorSettings()
                            }

                        Text(statusBarManualColorHexText)
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(statusBarAutoAdaptDraft ? .tertiary : .secondary)

                        Spacer(minLength: 8)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(isDarkTheme ? Color.white.opacity(0.05) : Color.white)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(separatorColor, lineWidth: 1)
                }

                StatusStyleQuickPicker(style: model.displayStyle) { style in
                    onSelectDisplayStyle?(style)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
    }

    private var codexAccordionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                isCodexPanelExpanded.toggle()
            }) {
                HStack(spacing: 8) {
                    Text("Codex 套餐")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Image(systemName: isCodexPanelExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isDarkTheme ? Color.white.opacity(0.05) : Color.white)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(separatorColor, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if isCodexPanelExpanded {
                codexExpandedLayout
            }
        }
    }

    private var statusBarManualColorHexText: String {
        let nsColor = NSColor(statusBarManualColorDraft).usingColorSpace(.sRGB)
            ?? NSColor(statusBarManualColorDraft).usingColorSpace(.deviceRGB)
            ?? .white
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func applyStatusBarColorSettings() {
        let mode: StatusBarForegroundMode = statusBarAutoAdaptDraft ? .autoAdapt : .manual
        let manualHex = statusBarManualColorHexText
        guard mode != model.statusBarForegroundMode
            || manualHex != model.statusBarManualColorHex else { return }
        onSetStatusBarColor?(mode, manualHex)
    }

    private func colorFromHex(_ rawValue: String) -> Color? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let hex = UInt32(value, radix: 16) else { return nil }
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }

    private var codexExpandedLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            subscriptionSummaryList

            HStack(spacing: 12) {
                quotaCard(
                    title: "今日配额",
                    symbol: "chart.bar",
                    ratioText: currencyRatioText(used: dailyUsedQuotaText, total: dailyTotalQuotaText),
                    percentText: todayPercentText,
                    progress: todayProgress
                )

                quotaCard(
                    title: "本周配额",
                    symbol: "calendar",
                    ratioText: weeklyRatioText,
                    percentText: weeklyPercentText,
                    progress: weekProgress
                )
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(metricTiles.indices, id: \.self) { index in
                    let tile = metricTiles[index]
                    metricTileView(tile)
                }
            }
        }
    }

    private var subscriptionSummaryList: some View {
        VStack(alignment: .leading, spacing: 10) {
            let items = codexPanelPackageItems
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                subscriptionSummaryCard(item)
            }
        }
    }

    private func subscriptionSummaryCard(_ item: SummaryPackageItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text("\(item.title) 订阅")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !item.badgeText.isEmpty {
                    packageBadgeText(item.badgeText, tone: item.badgeTone)
                }

                purchaseBadgeButton()

                Spacer(minLength: 8)

                Text(dailyPriceText)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            Text(item.subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.07) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
    }

    private var codexPanelPackageItems: [SummaryPackageItem] {
        if !model.packageItems.isEmpty {
            return model.packageItems
        }

        return [
            SummaryPackageItem(
                title: "未获取套餐数据",
                subtitle: model.footerText,
                badgeText: "",
                badgeTone: .neutral
            ),
        ]
    }

    private func packageBadgeText(_ text: String, tone: SummaryStatusTone) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(tone.swiftUIColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tone.swiftUIFillColor)
            .overlay {
                Capsule().stroke(tone.swiftUIBorderColor, lineWidth: 0.8)
            }
            .clipShape(Capsule())
    }

    private func purchaseBadgeButton() -> some View {
        Button(action: { onOpenPricing?() }) {
            Text("去购买")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(successBadgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(successBadgeColor.opacity(0.22))
                .overlay {
                    Capsule().stroke(successBadgeColor.opacity(0.32), lineWidth: 0.8)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func quotaCard(
        title: String,
        symbol: String,
        ratioText: String,
        percentText: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ratioText)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(percentText)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(isDarkTheme ? 0.08 : 0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(isDarkTheme ? 0.13 : 0.45))
                    Capsule()
                        .fill(Color(hex: 0x57BF71))
                        .frame(width: safeProgressWidth(totalWidth: proxy.size.width, progress: progress))
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.06) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
    }

    private func metricTileView(_ tile: MetricTile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tile.tint.opacity(isDarkTheme ? 0.18 : 0.12))
                .overlay {
                    Image(systemName: tile.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tile.tint)
                }
                .frame(width: 54, height: 54)

            Text(tile.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(tile.value)
                    .font(.system(size: 21, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)

                if let unit = tile.unit {
                    Text(unit)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.06) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
    }

    private var usageParts: (used: String, total: String) {
        let parts = model.usageValue.split(separator: "/", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if parts.count == 2 {
            return (parts[0], parts[1])
        }
        return (model.usageValue, "--")
    }

    private var codexDashboard: CodexDashboardMetrics {
        model.codexDashboard
    }

    private var dailyUsedQuotaText: String {
        if let value = codexDashboard.dailyUsedQuota {
            return formatCompactNumber(value)
        }
        return usageParts.used
    }

    private var dailyTotalQuotaText: String {
        if let value = codexDashboard.dailyTotalQuota {
            return formatCompactNumber(value)
        }
        return usageParts.total
    }

    private var todayPercentText: String {
        if let percent = codexDashboard.dailyUsedPercent {
            return formatPercent(percent)
        }
        return String(format: "%.0f%%", todayProgress * 100)
    }

    private var todayProgress: Double {
        if let percent = codexDashboard.dailyUsedPercent, percent.isFinite {
            return max(0, min(1, percent / 100))
        }
        if let used = codexDashboard.dailyUsedQuota,
           let total = codexDashboard.dailyTotalQuota,
           total > 0,
           used.isFinite,
           total.isFinite
        {
            return max(0, min(1, used / total))
        }
        guard let used = Double(usageParts.used), let total = Double(usageParts.total), total > 0 else {
            return 0
        }
        let ratio = used / total
        guard ratio.isFinite else { return 0 }
        return max(0, min(1, ratio))
    }

    private var weekProgress: Double {
        if let percent = codexDashboard.weeklyUsedPercent, percent.isFinite {
            return max(0, min(1, percent / 100))
        }
        if let used = codexDashboard.weeklyUsedQuota,
           let total = codexDashboard.weeklyTotalQuota,
           total > 0,
           used.isFinite,
           total.isFinite
        {
            return max(0, min(1, used / total))
        }
        if let progress = model.progress {
            guard progress.isFinite else { return 0 }
            return max(0, min(1, progress))
        }
        let normalized = model.progressValue.replacingOccurrences(of: "%", with: "")
        if let value = Double(normalized) {
            let ratio = value / 100
            guard ratio.isFinite else { return 0 }
            return max(0, min(1, ratio))
        }
        return 0
    }

    private var weeklyRatioText: String {
        if let used = codexDashboard.weeklyUsedQuota,
           let total = codexDashboard.weeklyTotalQuota
        {
            return currencyRatioText(used: formatCompactNumber(used), total: formatCompactNumber(total))
        }
        if let prefix = model.progressPrefix, !prefix.isEmpty {
            return currencyRatioText(from: prefix)
        }
        return currencyRatioText(from: model.usageValue)
    }

    private var weeklyPercentText: String {
        if let percent = codexDashboard.weeklyUsedPercent {
            return formatPercent(percent)
        }
        if model.progressValue == "--" {
            let fallback = model.progress.flatMap { $0.isFinite ? max(0, min(1, $0)) : nil } ?? 0
            return String(format: "%.0f%%", fallback * 100)
        }
        return model.progressValue
    }

    private var dailyPriceText: String {
        if let total = codexDashboard.dailyTotalQuota {
            guard total.isFinite else {
                return "$\(dailyTotalQuotaText)/天"
            }
            return String(format: "$%.2f/天", total)
        }
        if let total = Double(usageParts.total) {
            guard total.isFinite else {
                return "$\(usageParts.total)/天"
            }
            return String(format: "$%.2f/天", total)
        }
        return "$\(usageParts.total)/天"
    }

    private func safeProgressWidth(totalWidth: CGFloat, progress: Double) -> CGFloat {
        guard totalWidth.isFinite, totalWidth > 0, progress.isFinite else { return 8 }
        let clamped = max(0, min(1, progress))
        return max(8, totalWidth * clamped)
    }

    private struct MetricTile {
        let title: String
        let value: String
        let unit: String?
        let symbol: String
        let tint: Color
    }

    private var metricTiles: [MetricTile] {
        let requestCount = codexDashboard.requestCount.map { "\($0)" } ?? "--"
        let todayCostText = codexDashboard.totalCost.map { formatCurrency($0) } ?? "$\(usageParts.used)"
        let todayTokens = tokenDisplay(codexDashboard.totalTokens)
        let inputTokens = tokenDisplay(codexDashboard.inputTokens)
        let cacheTokens = tokenDisplay(codexDashboard.cachedInputTokens)
        let outputTokens = tokenDisplay(codexDashboard.outputTokens)

        return [
            MetricTile(title: "今日请求次数", value: requestCount, unit: "次", symbol: "arrow.triangle.2.circlepath", tint: Color(hex: 0x6D9EEB)),
            MetricTile(title: "今日消耗额度", value: todayCostText, unit: nil, symbol: "creditcard", tint: Color(hex: 0x57BF71)),
            MetricTile(title: "今日消耗 Token", value: todayTokens.value, unit: todayTokens.unit, symbol: "cpu", tint: Color(hex: 0xA87AE8)),
            MetricTile(title: "输入 Token", value: inputTokens.value, unit: inputTokens.unit, symbol: "arrow.down.left", tint: Color(hex: 0x7BA3FF)),
            MetricTile(title: "缓存 Token", value: cacheTokens.value, unit: cacheTokens.unit, symbol: "shippingbox", tint: Color(hex: 0x69C27D)),
            MetricTile(title: "输出 Token", value: outputTokens.value, unit: outputTokens.unit, symbol: "arrow.up.right", tint: Color(hex: 0xFFA95E)),
        ]
    }

    private func formatCompactNumber(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        let rounded = value.rounded()
        if abs(value - rounded) < 0.005 {
            return "\(Int(rounded))"
        }
        return String(format: "%.2f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        let clamped = max(0, min(100, value))
        let rounded = clamped.rounded()
        if abs(clamped - rounded) < 0.005 {
            return "\(Int(rounded))%"
        }
        return String(format: "%.2f%%", clamped)
    }

    private func formatCurrency(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        return String(format: "$%.2f", value)
    }

    private func currencyRatioText(used: String, total: String) -> String {
        "\(currencyAmountText(used)) / \(currencyAmountText(total))"
    }

    private func currencyRatioText(from raw: String) -> String {
        let parts = raw.split(separator: "/", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if parts.count == 2 {
            return currencyRatioText(used: parts[0], total: parts[1])
        }
        return currencyAmountText(raw)
    }

    private func currencyAmountText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "--" || trimmed.hasPrefix("$") {
            return trimmed
        }
        return "$\(trimmed)"
    }

    private func tokenDisplay(_ rawValue: Double?) -> (value: String, unit: String?) {
        guard let rawValue, rawValue.isFinite else {
            return ("--", nil)
        }

        let absolute = abs(rawValue)
        if absolute >= 1_000_000 {
            return (trimmedScaled(rawValue / 1_000_000), "M")
        }
        if absolute >= 1_000 {
            return (trimmedScaled(rawValue / 1_000), "k")
        }
        let rounded = Int(rawValue.rounded())
        return ("\(rounded)", nil)
    }

    private func trimmedScaled(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        var text = String(format: "%.2f", value)
        while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
            text.removeLast()
        }
        return text
    }

    private var usageRecordsContent: some View {
        let panel = model.codexUsageRecords
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Codex 使用日志")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                usageLogsCountBadge(panel: panel)

                Button(action: { onRefresh?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("刷新")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(isDarkTheme ? 0.07 : 0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().overlay(separatorColor)

            usageRecordsTableHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

            Divider().overlay(separatorColor)

            if let errorText = panel.errorText, !errorText.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF59E0B))
                    Text(errorText)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .padding(.vertical, 16)
            } else if panel.records.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("暂无使用记录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .padding(.vertical, 16)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(panel.records, id: \.id) { item in
                        usageRecordRow(item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        if item.id != panel.records.last?.id {
                            Divider().overlay(separatorColor)
                        }
                    }
                }
            }

            Divider().overlay(separatorColor)

            usageRecordsPaginationFooter
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.04) : Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(separatorColor, lineWidth: 1)
        }
    }

    private var usageRecordsTableColumnWeights: [CGFloat] {
        [1.7, 1.25, 2.1, 2.3, 0.65]
    }

    private var usageRecordsTableHeader: some View {
        GeometryReader { proxy in
            let columnWidths = usageRecordsTableColumnWidths(for: proxy.size.width)
            HStack(alignment: .center, spacing: usageRecordsTableColumnSpacing) {
                usageHeaderTitle("时间")
                    .frame(width: columnWidths[0], alignment: .leading)
                usageHeaderTitle("模型")
                    .frame(width: columnWidths[1], alignment: .leading)
                usageHeaderTitle("Tokens")
                    .frame(width: columnWidths[2], alignment: .leading)
                usageHeaderTitle("费用")
                    .frame(width: columnWidths[3], alignment: .leading)
                usageHeaderTitle("明细")
                    .frame(width: columnWidths[4], alignment: .leading)
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .frame(height: 14)
    }

    private func usageHeaderTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func usageRecordRow(_ item: CodexUsageRecordViewModel) -> some View {
        GeometryReader { proxy in
            let columnWidths = usageRecordsTableColumnWidths(for: proxy.size.width)
            HStack(alignment: .top, spacing: usageRecordsTableColumnSpacing) {
                Text(item.timestampText)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: columnWidths[0], alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.modelText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.tierText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: columnWidths[1], alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedUsageLogTokenText(for: item))
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .monospacedDigit()
                    Text(formattedTokenBreakdownText(item.tokenBreakdownText))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(width: columnWidths[2], alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.totalCostText)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .monospacedDigit()
                    Text(item.costBreakdownText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(width: columnWidths[3], alignment: .leading)

                Button(action: {
                    if let detailURL = item.detailURL, !detailURL.isEmpty {
                        onOpenUsageLogDetail?(detailURL)
                    } else {
                        onOpenDashboard?()
                    }
                }) {
                    Text("明细")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(successBadgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(successBadgeColor.opacity(0.12))
                        .overlay {
                            Capsule().stroke(successBadgeColor.opacity(0.22), lineWidth: 0.8)
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(width: columnWidths[4], alignment: .leading)
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .frame(height: 48)
    }

    private var usageRecordsTableColumnSpacing: CGFloat {
        10
    }

    private func usageRecordsTableColumnWidths(for totalWidth: CGFloat) -> [CGFloat] {
        let weights = usageRecordsTableColumnWeights
        let totalSpacing = usageRecordsTableColumnSpacing * CGFloat(max(weights.count - 1, 0))
        let contentWidth = max(0, totalWidth - totalSpacing)
        let weightSum = max(weights.reduce(CGFloat.zero, +), 1)
        return weights.map { contentWidth * ($0 / weightSum) }
    }

    @ViewBuilder
    private func usageLogsCountBadge(panel: CodexUsageRecordsPanelViewModel) -> some View {
        let resolvedCount = panel.totalCount ?? panel.records.count
        if resolvedCount > 0 {
            Text("共 \(resolvedCount.formatted()) 条")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(successBadgeColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(successBadgeColor.opacity(0.12))
                .overlay {
                    Capsule().stroke(successBadgeColor.opacity(0.22), lineWidth: 0.8)
                }
                .clipShape(Capsule())
        }
    }

    private var usageRecordsPaginationFooter: some View {
        let panel = model.codexUsageRecords
        let page = max(1, panel.page)
        let totalPages = resolvedUsageLogTotalPages
        let pageNumbers = usagePageNumbers(totalPages: totalPages, currentPage: page)
        let summaryText = usageRecordsSummaryText(panel: panel, page: page, totalPages: totalPages)

        return HStack(alignment: .center, spacing: 12) {
            Text(summaryText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 10)

            usagePaginationControlButton(
                iconName: "chevron.left.2",
                isDisabled: page <= 1,
                action: { onSelectUsageLogsPage?(1) }
            )

            usagePaginationControlButton(
                iconName: "chevron.left",
                isDisabled: page <= 1,
                action: { onSelectUsageLogsPage?(max(1, page - 1)) }
            )

            ForEach(pageNumbers, id: \.self) { pageNumber in
                Button(action: { onSelectUsageLogsPage?(pageNumber) }) {
                    Text("\(pageNumber)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(pageNumber == page ? usagePaginationSelectedTextColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .fill(pageNumber == page ? usagePaginationSelectedFillColor : Color.clear)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .stroke(separatorColor, lineWidth: pageNumber == page ? 0 : 0.8)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 8.5, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            usagePaginationControlButton(
                iconName: "chevron.right",
                isDisabled: page >= totalPages,
                action: { onSelectUsageLogsPage?(min(totalPages, page + 1)) }
            )

            usagePaginationControlButton(
                iconName: "chevron.right.2",
                isDisabled: page >= totalPages,
                action: { onSelectUsageLogsPage?(totalPages) }
            )
        }
    }

    private var usagePaginationSelectedFillColor: Color {
        successBadgeColor
    }

    private var usagePaginationSelectedTextColor: Color {
        if isCustomSkinSelected, customSkinBrightness > 0.74 {
            return Color.black.opacity(0.86)
        }
        return .white
    }

    private func usageRecordsSummaryText(
        panel: CodexUsageRecordsPanelViewModel,
        page: Int,
        totalPages: Int
    ) -> String {
        var summary = "第 \(page) / \(totalPages) 页"

        if let totalCount = panel.totalCount {
            summary += "，共 \(totalCount.formatted()) 条"
        }

        let tokensText = resolvedPageTokensText(panel: panel)
        let costText = resolvedPageCostText(panel: panel)

        if let tokensText, let costText {
            summary += " · 本页 \(tokensText) tokens / \(costText)"
        } else if let tokensText {
            summary += " · 本页 \(tokensText) tokens"
        } else if let costText {
            summary += " · 本页 \(costText)"
        }

        return summary
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolvedPageTokensText(panel: CodexUsageRecordsPanelViewModel) -> String? {
        if let pageTokensText = normalizedOptionalText(panel.pageTokensText) {
            let normalizedTokenText = pageTokensText
                .replacingOccurrences(of: #"(?i)\s*tokens?"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = parseNumericValue(from: normalizedTokenText) {
                return formatTokenIntegerText(value)
            }
            return formatLargeIntegersInText(normalizedTokenText)
        }

        let totals = panel.records.compactMap { record in
            if let rawValue = record.totalTokensValue, rawValue.isFinite {
                return rawValue
            }
            return parseNumericValue(from: record.totalTokensText)
        }

        guard !totals.isEmpty else { return nil }
        let sum = totals.reduce(0, +)
        return formatTokenIntegerText(sum)
    }

    private func resolvedPageCostText(panel: CodexUsageRecordsPanelViewModel) -> String? {
        if let pageCostText = normalizedOptionalText(panel.pageCostText) {
            return pageCostText
        }

        let totals = panel.records.compactMap { record in
            if let rawValue = record.totalCostValue, rawValue.isFinite {
                return rawValue
            }
            return parseNumericValue(from: record.totalCostText)
        }

        guard !totals.isEmpty else { return nil }
        let sum = totals.reduce(0, +)
        return "$\(trimmedDecimal(sum, maxDigits: 4))"
    }

    private func parseNumericValue(from text: String?) -> Double? {
        guard let text = normalizedOptionalText(text) else { return nil }
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    private func formattedUsageLogTokenText(for item: CodexUsageRecordViewModel) -> String {
        if let value = item.totalTokensValue, value.isFinite {
            return formatTokenIntegerText(value)
        }
        if let value = parseNumericValue(from: item.totalTokensText) {
            return formatTokenIntegerText(value)
        }
        return formatLargeIntegersInText(item.totalTokensText)
    }

    private func formattedTokenBreakdownText(_ rawText: String) -> String {
        formatLargeIntegersInText(rawText)
    }

    private func formatTokenIntegerText(_ value: Double) -> String {
        let rounded = Int64(value.rounded())
        return Self.usageSummaryIntegerFormatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
    }

    private func formatLargeIntegersInText(_ rawText: String) -> String {
        guard let regex = Self.largeIntegerRegex else { return rawText }
        let nsRange = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
        let matches = regex.matches(in: rawText, options: [], range: nsRange)
        guard !matches.isEmpty else { return rawText }

        var formatted = rawText
        for match in matches.reversed() {
            guard
                let range = Range(match.range, in: formatted),
                let value = Int64(formatted[range])
            else {
                continue
            }
            let replacement = Self.usageSummaryIntegerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
            formatted.replaceSubrange(range, with: replacement)
        }
        return formatted
    }

    private func trimmedDecimal(_ value: Double, maxDigits: Int) -> String {
        var text = String(format: "%.\(maxDigits)f", value)
        while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
            text.removeLast()
        }
        return text
    }

    private func usagePaginationControlButton(
        iconName: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                        .fill(Color.clear)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                        .stroke(separatorColor, lineWidth: 0.8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 8.5, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
    }

    private var resolvedUsageLogTotalPages: Int {
        let panel = model.codexUsageRecords
        if let pages = panel.totalPages, pages > 0 {
            return pages
        }
        if let count = panel.totalCount, panel.pageSize > 0 {
            return max(1, Int(ceil(Double(count) / Double(panel.pageSize))))
        }
        return max(1, panel.page)
    }

    private func usagePageNumbers(totalPages: Int, currentPage: Int) -> [Int] {
        let clampedCurrent = max(1, min(totalPages, currentPage))
        let lower = max(1, clampedCurrent - 2)
        let upper = min(totalPages, clampedCurrent + 2)
        return Array(lower ... upper)
    }

    private static let usageSummaryIntegerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let largeIntegerRegex = try? NSRegularExpression(pattern: #"(?<![\d.])\d{4,}(?![\d.])"#)
}

final class StatusSummaryView: NSView {
    static let preferredWidth: CGFloat = 1008
    static let preferredHeight: CGFloat = 647

    var onTogglePanelMode: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onToggleEmail: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onRefresh: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSelectStatisticsMode: ((StatisticsDisplayMode) -> Void)? {
        didSet { updateRootView() }
    }
    var onSelectSource: ((PackageSource) -> Void)? {
        didSet { updateRootView() }
    }
    var onSetAPIKey: ((PackageSource, String) -> Void)? {
        didSet { updateRootView() }
    }
    var onSetInterval: ((Double) -> Void)? {
        didSet { updateRootView() }
    }
    var onOpenDashboard: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onOpenPricing: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSelectDisplayStyle: ((StatusDisplayStyle) -> Void)? {
        didSet { updateRootView() }
    }
    var onToggleSourceGroup: ((PackageSource) -> Void)? {
        didSet { updateRootView() }
    }
    var onToggleLaunchAtLogin: ((Bool) -> Void)? {
        didSet { updateRootView() }
    }
    var onConfigureMCP: ((Bool, UInt16) -> Void)? {
        didSet { updateRootView() }
    }
    var onSetStatusBarColor: ((StatusBarForegroundMode, String) -> Void)? {
        didSet { updateRootView() }
    }
    var onSelectUsageLogsPage: ((Int) -> Void)? {
        didSet { updateRootView() }
    }
    var onOpenUsageLogDetail: ((String) -> Void)? {
        didSet { updateRootView() }
    }

    private var model = StatusSummaryViewModel.placeholder
    private let hostingView: NSHostingView<MonitorDashboardShellView>

    override var intrinsicContentSize: NSSize {
        let size = hostingView.fittingSize
        return NSSize(width: max(Self.preferredWidth, size.width), height: max(Self.preferredHeight, size.height))
    }

    override init(frame frameRect: NSRect) {
        hostingView = NSHostingView(
            rootView: MonitorDashboardShellView(
                model: .placeholder,
                onTogglePanelMode: nil,
                onToggleEmail: nil,
                onRefresh: nil,
                onSelectStatisticsMode: nil,
                onSelectSource: nil,
                onSetAPIKey: nil,
                onSetInterval: nil,
                onOpenDashboard: nil,
                onOpenPricing: nil,
                onSelectDisplayStyle: nil,
                onToggleSourceGroup: nil,
                onToggleLaunchAtLogin: nil,
                onConfigureMCP: nil,
                onSetStatusBarColor: nil,
                onSelectUsageLogsPage: nil,
                onOpenUsageLogDetail: nil
            )
        )
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ model: StatusSummaryViewModel) {
        self.model = model
        updateRootView()
    }

    private func updateRootView() {
        hostingView.rootView = MonitorDashboardShellView(
            model: model,
            onTogglePanelMode: onTogglePanelMode,
            onToggleEmail: onToggleEmail,
            onRefresh: onRefresh,
            onSelectStatisticsMode: onSelectStatisticsMode,
            onSelectSource: onSelectSource,
            onSetAPIKey: onSetAPIKey,
            onSetInterval: onSetInterval,
            onOpenDashboard: onOpenDashboard,
            onOpenPricing: onOpenPricing,
            onSelectDisplayStyle: onSelectDisplayStyle,
            onToggleSourceGroup: onToggleSourceGroup,
            onToggleLaunchAtLogin: onToggleLaunchAtLogin,
            onConfigureMCP: onConfigureMCP,
            onSetStatusBarColor: onSetStatusBarColor,
            onSelectUsageLogsPage: onSelectUsageLogsPage,
            onOpenUsageLogDetail: onOpenUsageLogDetail
        )
        layoutSubtreeIfNeeded()
        invalidateIntrinsicContentSize()
    }
}
