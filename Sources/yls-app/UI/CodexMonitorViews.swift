import AppKit
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
    func liquidGlassCapsule() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self
                .background {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.regular, in: Capsule())
                }
                .overlay {
                    Capsule().stroke(.quaternary, lineWidth: 0.8)
                }
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(.quaternary, lineWidth: 0.8)
                }
        }
        #else
        self
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(.quaternary, lineWidth: 0.8)
            }
        #endif
    }

    @ViewBuilder
    func compactSurface(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self
                .background {
                    ZStack {
                        Rectangle()
                            .fill(.clear)
                            .glassEffect(.regular, in: shape)
                        shape
                            .fill(tint)
                    }
                }
                .overlay {
                    shape.stroke(.quaternary, lineWidth: 0.8)
                }
        } else {
            self
                .background {
                    ZStack {
                        shape
                            .fill(.ultraThinMaterial)
                        shape
                            .fill(tint)
                    }
                }
                .overlay {
                    shape.stroke(.quaternary, lineWidth: 0.8)
                }
        }
        #else
        self
            .background {
                ZStack {
                    shape
                        .fill(.ultraThinMaterial)
                    shape
                        .fill(tint)
                }
            }
            .overlay {
                shape.stroke(.quaternary, lineWidth: 0.8)
            }
        #endif
    }

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
        elevated: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let fill: Color
        let border: Color

        if colorScheme == .dark {
            fill = elevated ? Color.white.opacity(0.07) : Color.white.opacity(0.05)
            border = Color.white.opacity(0.11)
        } else {
            fill = elevated ? Color.white.opacity(0.98) : Color.white.opacity(0.92)
            border = Color.black.opacity(0.08)
        }

        return self
            .background(shape.fill(fill))
            .overlay {
                shape.stroke(border, lineWidth: 0.8)
            }
    }
}

struct MenuActionButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let prominent: Bool
    let action: (() -> Void)?
    let useInfoCardBackground: Bool

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        subtitle: String?,
        systemImage: String,
        prominent: Bool,
        action: (() -> Void)?,
        useInfoCardBackground: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.prominent = prominent
        self.action = action
        self.useInfoCardBackground = useInfoCardBackground
    }

    private var compactTint: Color {
        prominent
            ? (isHovered ? .secondary.opacity(0.14) : .secondary.opacity(0.08))
            : (isHovered ? .primary.opacity(0.10) : .primary.opacity(0.04))
    }

    @ViewBuilder
    private func applySurface<Content: View>(to content: Content) -> some View {
        if useInfoCardBackground {
            content
                .summaryDashboardSurface(cornerRadius: 15, colorScheme: colorScheme, elevated: true)
        } else {
            content
                .compactSurface(
                    cornerRadius: 15,
                    tint: compactTint
                )
        }
    }

    var body: some View {
        Button(action: { action?() }) {
            applySurface(
                to: HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(prominent ? .primary : .secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                        )

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
            .overlay {
                if prominent, !useInfoCardBackground {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.tertiary, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct StyleChipButton: View {
    let style: StatusDisplayStyle
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: style.selectorSymbol)
                        .font(.system(size: 11, weight: .semibold))
                    Text(style.chipTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
                .foregroundStyle(isSelected ? .primary : .secondary)

                Text(style.selectorPreview)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentMaterialSurface(
                cornerRadius: 13,
                tint: isSelected
                    ? .secondary.opacity(0.16)
                    : (isHovered ? .primary.opacity(0.08) : .clear)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.tertiary, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
    @Environment(\.colorScheme) private var colorScheme

    init(
        model: SourceSummaryGroupViewModel,
        codexDashboard: CodexDashboardMetrics = .empty,
        onToggle: (() -> Void)? = nil
    ) {
        self.model = model
        self.codexDashboard = codexDashboard
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

                    Spacer(minLength: 8)

                    Text("余: \(model.remainingValue)")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(model.statusText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(model.statusTone.swiftUIColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(model.statusTone.swiftUIFillColor)
                        .overlay {
                            Capsule().stroke(model.statusTone.swiftUIBorderColor, lineWidth: 0.8)
                        }
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if !model.footerText.isEmpty {
                Text(model.footerText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if model.isExpanded {
                if model.source == .codex, hasCodexDashboardData {
                    codexExpandedContent
                } else {
                    defaultExpandedContent
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .summaryDashboardSurface(cornerRadius: 16, colorScheme: colorScheme)
    }

    private var defaultExpandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            WeightedMetricRowLayout(weights: [3, 3, 4], spacing: 8) {
                ForEach(Array(summaryCards.enumerated()), id: \.offset) { _, card in
                    metricCard(title: card.title, value: card.value, lineLimit: card.lineLimit)
                }
            }

            if !model.packageItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("套餐")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(model.packageItems.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(item.subtitle)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Spacer(minLength: 6)

                            Text(item.badgeText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(item.badgeTone.swiftUIColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(item.badgeTone.swiftUIFillColor)
                                .overlay {
                                    Capsule().stroke(item.badgeTone.swiftUIBorderColor, lineWidth: 0.8)
                                }
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .summaryDashboardSurface(cornerRadius: 13, colorScheme: colorScheme, elevated: true)
                    }
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

    private var codexExpandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            codexSubscriptionSummaryCard

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

            usageProgressCard(
                title: model.progressLabel,
                prefixText: model.progressPrefix,
                valueText: model.progressValue,
                progress: model.progress ?? 0
            )
        }
    }

    private var codexSubscriptionSummaryCard: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("codex \(model.packageItems.first?.title ?? "Basic") 订阅")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let badge = model.packageItems.first?.badgeText, !badge.isEmpty {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(model.packageItems.first?.badgeTone.swiftUIColor ?? .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(model.packageItems.first?.badgeTone.swiftUIFillColor ?? Color.clear)
                            .overlay {
                                Capsule().stroke(model.packageItems.first?.badgeTone.swiftUIBorderColor ?? Color.clear, lineWidth: 0.8)
                            }
                            .clipShape(Capsule())
                    }
                }

                Text(model.packageItems.first?.subtitle ?? "到期 \(model.renewalValue)")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text("\(currencyAmountText(codexDashboard.dailyTotalQuota ?? 0))/天")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .summaryDashboardSurface(cornerRadius: 13, colorScheme: colorScheme, elevated: true)
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
        .summaryDashboardSurface(cornerRadius: 13, colorScheme: colorScheme, elevated: true)
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
    }

    private var summaryCards: [MetricCardContent] {
        if model.source == .codex, hasCodexDashboardData {
            return codexSummaryCards
        }
        return [
            MetricCardContent(title: "剩余", value: model.remainingValue, lineLimit: 1),
            MetricCardContent(title: model.usageLabel, value: model.usageValue, lineLimit: 1),
            MetricCardContent(title: model.renewalLabel, value: model.renewalValue, lineLimit: 2),
        ]
    }

    private var codexSummaryCards: [MetricCardContent] {
        let dailyRatio = quotaRatioText(used: codexDashboard.dailyUsedQuota, total: codexDashboard.dailyTotalQuota)
            ?? currencyRatioText(from: model.usageValue)
        let weeklyRawRatio = quotaRatioText(used: codexDashboard.weeklyUsedQuota, total: codexDashboard.weeklyTotalQuota)
            ?? model.progressPrefix
            ?? model.usageValue
        let weeklyRatio = currencyRatioText(from: weeklyRawRatio)
        let dailyPercent = quotaPercentText(
            directPercent: codexDashboard.dailyUsedPercent,
            used: codexDashboard.dailyUsedQuota,
            total: codexDashboard.dailyTotalQuota
        )
        let weeklyPercent = quotaPercentText(
            directPercent: codexDashboard.weeklyUsedPercent,
            used: codexDashboard.weeklyUsedQuota,
            total: codexDashboard.weeklyTotalQuota
        ) ?? (model.progressValue == "--" ? nil : model.progressValue)
        let requestCountText = codexDashboard.requestCount.map { "\($0) 次" } ?? "--"

        return [
            MetricCardContent(
                title: "今日配额",
                value: quotaValueText(ratio: dailyRatio, percent: dailyPercent),
                lineLimit: 2
            ),
            MetricCardContent(
                title: "本周配额",
                value: quotaValueText(ratio: weeklyRatio, percent: weeklyPercent),
                lineLimit: 2
            ),
            MetricCardContent(title: "今日请求次数", value: requestCountText, lineLimit: 1),
        ]
    }

    private var hasCodexDashboardData: Bool {
        codexDashboard.dailyUsedQuota != nil
            || codexDashboard.dailyTotalQuota != nil
            || codexDashboard.weeklyUsedQuota != nil
            || codexDashboard.weeklyTotalQuota != nil
            || codexDashboard.requestCount != nil
    }

    private func quotaValueText(ratio: String, percent: String?) -> String {
        guard let percent, !percent.isEmpty else {
            return ratio
        }
        return "\(ratio) · \(percent)"
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
        .summaryDashboardSurface(cornerRadius: 13, colorScheme: colorScheme, elevated: true)
    }
}

struct LiquidGlassSummaryPanel: View {
    let model: StatusSummaryViewModel
    let onTogglePanelMode: (() -> Void)?
    let onToggleEmail: (() -> Void)?
    let onRefresh: (() -> Void)?
    let onSelectStatisticsMode: (() -> Void)?
    let onSelectSource: (() -> Void)?
    let onSetAPIKey: (() -> Void)?
    let onSetAGIKey: (() -> Void)?
    let onSetInterval: (() -> Void)?
    let onOpenDashboard: (() -> Void)?
    let onOpenPricing: (() -> Void)?
    let onSelectDisplayStyle: ((StatusDisplayStyle) -> Void)?
    let onToggleSourceGroup: ((PackageSource) -> Void)?
    let onToggleLaunchAtLogin: ((Bool) -> Void)?
    let onConfigureMCP: (() -> Void)?
    let onConfigureStatusColor: (() -> Void)?
    let onQuit: (() -> Void)?
    let showsHeaderRow: Bool

    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedGroups: Set<StatisticsGroupKind> = Set(StatisticsGroupKind.allCases)
    @State private var isStatusBarSettingsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if showsHeaderRow {
                headerRow
            }
            if model.panelMode == .statistics {
                statisticsPage
            } else {
                settingsPage
            }
        }
        .padding(12)
        .frame(width: 316)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statisticsPage: some View {
        VStack(alignment: .leading, spacing: 9) {
            if model.statisticsDisplayMode == .dual {
                dualContentPanel
            } else {
                metaRow
                contentPanel
            }
        }
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 9) {
            settingsHeaderBanner
            settingsActionPanel
        }
    }

    private var settingsHeaderBanner: some View {
        HStack(spacing: 10) {
            Label("设置模式", systemImage: "slider.horizontal.3")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 6)

            Text(model.statisticsModeText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.92)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 16, tint: Color.white.opacity(0.20))
    }

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            heroPanel
            packageSection
            progressSection
        }
    }

    private var dualContentPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(model.sourceGroups.enumerated()), id: \.element.source.rawValue) { _, group in
                SourceSummaryGroupView(model: group, codexDashboard: model.codexDashboard) {
                    onToggleSourceGroup?(group.source)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 8) {
                Text(model.title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if model.statisticsDisplayMode == .single {
                    Text(model.currentSourceTitle)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                statusBadge(
                    text: model.statusText,
                    tone: model.statusTone,
                    action: isRefreshableStatus(model.statusTone) ? onRefresh : nil
                )

                if shouldShowHeaderPanelToggle {
                    Button(action: togglePanelMode) {
                        Image(systemName: model.panelMode.toggleSymbol)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .modifier(GlassCapsuleModifier(glassNamespace: glassNamespace, id: "panel-mode-toggle"))
                }
            }
        }
    }

    private var shouldShowHeaderPanelToggle: Bool {
        model.panelMode == .settings
            || model.statisticsDisplayMode == .dual
            || !model.canToggleEmail
    }

    private var metaRow: some View {
        EmptyView()
    }

    private var emailControls: some View {
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

            Button(action: { onToggleEmail?() }) {
                Image(systemName: model.isEmailVisible ? "eye.slash" : "eye")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .fixedSize(horizontal: true, vertical: false)
        .modifier(GlassCapsuleModifier(glassNamespace: glassNamespace, id: "email-pill"))
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("套餐剩余额度")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(model.remainingValue)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            HStack(alignment: .top, spacing: 8) {
                compactMetric(
                    title: model.usageLabel,
                    value: model.usageValue,
                    alignment: .leading
                )
                .frame(width: 94, alignment: .leading)

                renewalMetricCard
                .layoutPriority(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 18)
    }

    @ViewBuilder
    private var packageSection: some View {
        if let title = model.packageSectionTitle, !model.packageItems.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 6)

                    Text("\(model.packageItems.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(model.packageItems.enumerated()), id: \.offset) { _, item in
                        packageRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func packageRow(_ item: SummaryPackageItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(item.badgeText)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(item.badgeTone.swiftUIColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.badgeTone.swiftUIFillColor)
                        .overlay {
                            Capsule().stroke(item.badgeTone.swiftUIBorderColor, lineWidth: 0.8)
                        }
                        .clipShape(Capsule())
                }

                Text(item.subtitle)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 15)
    }

    @ViewBuilder
    private var mountedModulesSection: some View {
        if !model.mountedModules.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(model.mountedModules.enumerated()), id: \.offset) { index, module in
                    mountedModuleContent(
                        module,
                        showsTitle: model.mountedModules.count > 1
                    )

                    if index < model.mountedModules.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 1)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func mountedModuleContent(
        _ module: MountedPackageModuleSummary,
        showsTitle: Bool
    ) -> some View {
        let topMetricMinHeight: CGFloat = 78

        return VStack(alignment: .leading, spacing: 8) {
            if showsTitle {
                Text(module.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 8) {
                compactMetric(
                    title: module.remainingLabel,
                    value: module.remainingValue,
                    alignment: .leading,
                    valueFontSize: 16,
                    valueMinimumScaleFactor: 0.68,
                    cardMinHeight: topMetricMinHeight
                )

                compactMetric(
                    title: module.usageLabel,
                    value: module.usageValue,
                    alignment: .leading,
                    valueFontSize: 11,
                    valueMinimumScaleFactor: 0.76,
                    cardMinHeight: topMetricMinHeight
                )
            }

            compactMetric(
                title: module.renewalLabel,
                value: module.renewalValue,
                alignment: .leading,
                valueFontSize: 11,
                valueMinimumScaleFactor: 0.76
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(module.progressLabel)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Text(module.progressValue)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                GeometryReader { proxy in
                    let value = module.progress ?? 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.92), .accentColor.opacity(0.42)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, proxy.size.width * value))
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentMaterialSurface(cornerRadius: 15)

            if let packageSectionTitle = module.packageSectionTitle {
                VStack(alignment: .leading, spacing: 7) {
                    Text(packageSectionTitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(module.packageItems.enumerated()), id: \.offset) { _, item in
                            packageRow(item)
                        }
                    }
                }
            }

            if !module.footerText.isEmpty {
                Text(module.footerText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func statisticsGroup<Content: View>(
        kind: StatisticsGroupKind,
        title: String,
        systemImage: String,
        accessory: StatisticsGroupAccessory,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button(action: { toggleStatisticsGroup(kind) }) {
                    HStack(spacing: 8) {
                        Label(title, systemImage: systemImage)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let tone = accessory.tone {
                    statusBadge(
                        text: accessory.text,
                        tone: tone,
                        action: isRefreshableStatus(tone) ? onRefresh : nil
                    )
                } else {
                    groupAccessoryChip(accessory.text)
                }

                Button(action: { toggleStatisticsGroup(kind) }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isGroupExpanded(kind) ? 0 : -90))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if isGroupExpanded(kind) {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 20, tint: Color.white.opacity(0.14))
    }

    private func groupAccessoryChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.10))
            .overlay {
                Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            }
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func statusBadge(
        text: String,
        tone: SummaryStatusTone,
        action: (() -> Void)?
    ) -> some View {
        let badge = Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tone.swiftUIColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(tone.swiftUIFillColor)
            .overlay {
                Capsule().stroke(tone.swiftUIBorderColor, lineWidth: 0.8)
            }
            .clipShape(Capsule())

        if let action {
            Button(action: action) {
                badge
            }
            .buttonStyle(.plain)
            .help("状态异常，点击立即刷新")
        } else {
            badge
        }
    }

    private func isRefreshableStatus(_ tone: SummaryStatusTone) -> Bool {
        tone == .critical
    }

    private func isGroupExpanded(_ kind: StatisticsGroupKind) -> Bool {
        expandedGroups.contains(kind)
    }

    private func toggleStatisticsGroup(_ kind: StatisticsGroupKind) {
        let toggle = {
            if expandedGroups.contains(kind) {
                expandedGroups.remove(kind)
            } else {
                expandedGroups.insert(kind)
            }
        }

        if reduceMotion {
            toggle()
            return
        }

        withAnimation(.spring(duration: 0.30, bounce: 0.18)) {
            toggle()
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(model.progressLabel)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    if let progressPrefix = model.progressPrefix {
                        Text(progressPrefix)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                    }

                    Text(model.progressValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            }

            GeometryReader { proxy in
                let value = model.progress ?? 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.92),
                                    .accentColor.opacity(0.42)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * value))
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 15)
    }

    @ViewBuilder
    private var settingsActionPanel: some View {
        settingsControls
            .padding(.top, 2)
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.primary.opacity(0.14))
                .frame(height: 1)
                .padding(.bottom, 2)

            MenuActionButton(
                title: "统计模式",
                subtitle: model.statisticsModeText,
                systemImage: "square.split.2x1",
                prominent: false,
                action: onSelectStatisticsMode,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "单显套餐源",
                subtitle: model.currentSourceTitle,
                systemImage: "square.stack.3d.up",
                prominent: false,
                action: onSelectSource,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "开机自启",
                subtitle: model.launchAtLoginSupported
                    ? (model.launchAtLoginEnabled ? "已开启" : "已关闭")
                    : "仅支持 macOS 13+",
                systemImage: model.launchAtLoginEnabled ? "power.circle.fill" : "power.circle",
                prominent: false,
                action: model.launchAtLoginSupported
                    ? { onToggleLaunchAtLogin?(!model.launchAtLoginEnabled) }
                    : nil,
                useInfoCardBackground: true
            )

            statusBarSettingsPanel

            MenuActionButton(
                title: PackageSource.codex.keyButtonTitle,
                subtitle: model.codexAPIKeyStatusText,
                systemImage: "key.horizontal",
                prominent: false,
                action: onSetAPIKey,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: PackageSource.agi.keyButtonTitle,
                subtitle: model.agiAPIKeyStatusText,
                systemImage: "key.horizontal",
                prominent: false,
                action: onSetAGIKey,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "轮询间隔",
                subtitle: model.pollIntervalText,
                systemImage: "timer",
                prominent: false,
                action: onSetInterval,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "MCP 服务",
                subtitle: model.mcpStatusText,
                systemImage: "server.rack",
                prominent: false,
                action: onConfigureMCP,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "立即刷新",
                subtitle: nil,
                systemImage: "arrow.clockwise",
                prominent: true,
                action: onRefresh,
                useInfoCardBackground: true
            )

            if model.canOpenDashboard {
                MenuActionButton(
                    title: model.dashboardActionTitle,
                    subtitle: nil,
                    systemImage: "safari",
                    prominent: false,
                    action: onOpenDashboard,
                    useInfoCardBackground: true
                )
            }

            MenuActionButton(
                title: "退出",
                subtitle: nil,
                systemImage: "power",
                prominent: false,
                action: onQuit,
                useInfoCardBackground: true
            )
        }
    }

    private var statusBarSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggleStatusBarSettings) {
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
                            .minimumScaleFactor(0.86)
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
                .contentMaterialSurface(cornerRadius: 15, tint: Color.white.opacity(0.12))
            }
            .buttonStyle(.plain)

            if isStatusBarSettingsExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    MenuActionButton(
                        title: "文本颜色",
                        subtitle: model.statusBarColorText,
                        systemImage: "paintpalette",
                        prominent: false,
                        action: onConfigureStatusColor,
                        useInfoCardBackground: true
                    )

                    displayStyleSection
                }
            }
        }
    }

    private var displayStyleSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("状态栏样式")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 6)

                Text(model.displayStyle.chipTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12))
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.26), lineWidth: 0.8)
                    }
                    .clipShape(Capsule())
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(StatusDisplayStyle.allCases, id: \.rawValue) { style in
                    StyleChipButton(
                        style: style,
                        isSelected: style == model.displayStyle
                    ) {
                        applyDisplayStyle(style)
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 16, tint: Color.white.opacity(0.18))
    }

    private func applyDisplayStyle(_ style: StatusDisplayStyle) {
        guard style != model.displayStyle else { return }
        if reduceMotion {
            onSelectDisplayStyle?(style)
            return
        }
        withAnimation(.spring(duration: 0.32, bounce: 0.20)) {
            onSelectDisplayStyle?(style)
        }
    }

    private func togglePanelMode() {
        if reduceMotion {
            onTogglePanelMode?()
            return
        }
        withAnimation(.spring(duration: 0.28, bounce: 0.15)) {
            onTogglePanelMode?()
        }
    }

    private func toggleStatusBarSettings() {
        isStatusBarSettingsExpanded.toggle()
    }

    private func compactMetric(
        title: String,
        value: String,
        alignment: HorizontalAlignment,
        valueFontSize: CGFloat = 12,
        valueLineLimit: Int = 1,
        valueMinimumScaleFactor: CGFloat = 0.72,
        cardMinHeight: CGFloat = 0
    ) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(valueLineLimit)
                .minimumScaleFactor(valueMinimumScaleFactor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 14)
    }

    private var renewalMetricCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.renewalLabel)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                if model.canOpenPricing {
                    Button(action: { onOpenPricing?() }) {
                        Text("去续费")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(model.renewalValue)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 14)
    }
}

private enum DashboardTab: String, CaseIterable {
    case usageOverview
    case usageRecords

    var title: String {
        switch self {
        case .usageOverview:
            return "使用情况"
        case .usageRecords:
            return "使用记录"
        }
    }

    var systemImage: String {
        switch self {
        case .usageOverview:
            return "chart.bar"
        case .usageRecords:
            return "clock.arrow.circlepath"
        }
    }
}

struct MonitorDashboardShellView: View {
    let model: StatusSummaryViewModel
    let onTogglePanelMode: (() -> Void)?
    let onToggleEmail: (() -> Void)?
    let onRefresh: (() -> Void)?
    let onSelectStatisticsMode: (() -> Void)?
    let onSelectSource: (() -> Void)?
    let onSetAPIKey: (() -> Void)?
    let onSetAGIKey: (() -> Void)?
    let onSetInterval: (() -> Void)?
    let onOpenDashboard: (() -> Void)?
    let onOpenPricing: (() -> Void)?
    let onSelectDisplayStyle: ((StatusDisplayStyle) -> Void)?
    let onToggleSourceGroup: ((PackageSource) -> Void)?
    let onToggleLaunchAtLogin: ((Bool) -> Void)?
    let onConfigureMCP: (() -> Void)?
    let onConfigureStatusColor: (() -> Void)?
    let onQuit: (() -> Void)?
    let onSelectUsageLogsPage: ((Int) -> Void)?
    let onOpenUsageLogDetail: ((String) -> Void)?

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var selectedTab: DashboardTab = .usageOverview
    @State private var isCodexPanelExpanded = true
    @State private var isStatusBarSettingsExpanded = false
    @State private var isSkinSettingsPageVisible = false
    @State private var selectedSkinSourceRawValue = SkinSourceOption.official.rawValue
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
        return themeAccentColor.opacity(0.16)
    }

    private var selectedSkinSourceStrokeColor: Color {
        if isCustomSkinSelected, customSkinBrightness < 0.28 {
            return Color.white.opacity(0.24)
        }
        return themeAccentColor.opacity(0.32)
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
        return isDarkTheme ? Color.white.opacity(0.10) : Color.white
    }

    private var selectedTabStrokeColor: Color {
        if isCustomSkinSelected {
            return customSkinColor.opacity(0.34)
        }
        return isDarkTheme ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
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
        VStack(spacing: 0) {
            topBar

            HStack(spacing: 0) {
                sidebar
                mainContent
            }
        }
        .background(windowBackgroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, effectiveColorScheme)
        .tint(themeAccentColor)
        .animation(themeTransitionAnimation, value: selectedSkinThemeRawValue)
        .animation(themeTransitionAnimation, value: selectedSkinSourceRawValue)
        .animation(themeTransitionAnimation, value: customSkinHue)
        .animation(themeTransitionAnimation, value: customSkinBrightness)
    }

    private var topBar: some View {
        HStack(spacing: 0) {
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
            .frame(width: sidebarWidth, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .center)
            .background(sidebarBackgroundColor)

            HStack(spacing: 8) {
                Text(model.footerText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 10)
                topBarAccountCapsule

                topBarIconButton(systemImage: "gearshape", action: handleSettingsButton)
                topBarIconButton(
                    systemImage: "tshirt",
                    action: toggleSkinSettingsPage
                )
                topBarIconButton(systemImage: "uiwindow.split.2x1", action: nil)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(contentBackgroundColor)
        }
        .frame(height: 38)
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
        VStack(alignment: .leading, spacing: 8) {
            ForEach(DashboardTab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 18)
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
            .foregroundStyle(isSelected ? .primary : .secondary)
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
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                if isSkinSettingsPageVisible {
                    skinSettingsPage
                } else if model.panelMode == .settings {
                    settingsPage
                } else {
                    if selectedTab == .usageOverview {
                        usageOverviewContent
                    } else {
                        usageRecordsContent
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 28)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .fill(themeAccentColor)
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
                .foregroundStyle(isSelected ? visibleThemeAccentColor : unselectedSkinSourceForegroundColor)
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
                                        ? themeAccentColor.opacity(0.5)
                                        : separatorColor,
                                    lineWidth: isSelected ? 1.2 : 1
                                )
                        }

                    if isSelected {
                        Circle()
                            .fill(themeAccentColor)
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
                    SourceSummaryGroupView(model: group, codexDashboard: model.codexDashboard) {
                        onToggleSourceGroup?(group.source)
                    }
                }
            } else {
                if let group = singleModeSourceGroup {
                    SourceSummaryGroupView(
                        model: group,
                        codexDashboard: group.source == .codex ? model.codexDashboard : .empty
                    ) {
                        onToggleSourceGroup?(group.source)
                    }
                } else {
                    codexAccordionPanel
                }
            }
        }
    }

    private var singleModeSourceGroup: SourceSummaryGroupViewModel? {
        if let matched = model.sourceGroups.first(where: { $0.source.chipTitle == model.currentSourceTitle }) {
            return matched
        }
        return model.sourceGroups.first(where: { $0.source == .codex }) ?? model.sourceGroups.first
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("设置模式", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 6)
                Text(model.statisticsModeText)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isDarkTheme ? Color.white.opacity(0.05) : Color.white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(separatorColor, lineWidth: 1)
            }

            MenuActionButton(
                title: "统计模式",
                subtitle: model.statisticsModeText,
                systemImage: "square.split.2x1",
                prominent: false,
                action: onSelectStatisticsMode,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "单显套餐源",
                subtitle: model.currentSourceTitle,
                systemImage: "square.stack.3d.up",
                prominent: false,
                action: onSelectSource,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "开机自启",
                subtitle: model.launchAtLoginSupported
                    ? (model.launchAtLoginEnabled ? "已开启" : "已关闭")
                    : "仅支持 macOS 13+",
                systemImage: model.launchAtLoginEnabled ? "power.circle.fill" : "power.circle",
                prominent: false,
                action: model.launchAtLoginSupported
                    ? { onToggleLaunchAtLogin?(!model.launchAtLoginEnabled) }
                    : nil,
                useInfoCardBackground: true
            )

            statusBarSettingsPanel

            MenuActionButton(
                title: PackageSource.codex.keyButtonTitle,
                subtitle: model.codexAPIKeyStatusText,
                systemImage: "key.horizontal",
                prominent: false,
                action: onSetAPIKey,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: PackageSource.agi.keyButtonTitle,
                subtitle: model.agiAPIKeyStatusText,
                systemImage: "key.horizontal",
                prominent: false,
                action: onSetAGIKey,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "轮询间隔",
                subtitle: model.pollIntervalText,
                systemImage: "timer",
                prominent: false,
                action: onSetInterval,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "MCP 服务",
                subtitle: model.mcpStatusText,
                systemImage: "server.rack",
                prominent: false,
                action: onConfigureMCP,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "立即刷新",
                subtitle: nil,
                systemImage: "arrow.clockwise",
                prominent: true,
                action: onRefresh,
                useInfoCardBackground: true
            )

            if model.canOpenDashboard {
                MenuActionButton(
                    title: model.dashboardActionTitle,
                    subtitle: nil,
                    systemImage: "safari",
                    prominent: false,
                    action: onOpenDashboard,
                    useInfoCardBackground: true
                )
            }

            MenuActionButton(
                title: "退出",
                subtitle: nil,
                systemImage: "power",
                prominent: false,
                action: onQuit,
                useInfoCardBackground: true
            )
        }
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
                MenuActionButton(
                    title: "文本颜色",
                    subtitle: model.statusBarColorText,
                    systemImage: "paintpalette",
                    prominent: false,
                    action: onConfigureStatusColor,
                    useInfoCardBackground: true
                )

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(StatusDisplayStyle.allCases, id: \.rawValue) { style in
                        StyleChipButton(
                            style: style,
                            isSelected: style == model.displayStyle
                        ) {
                            onSelectDisplayStyle?(style)
                        }
                    }
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

    private var codexExpandedLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            subscriptionSummaryCard

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

    private var subscriptionSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text(subscriptionTitleText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(remainingDaysBadgeText)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2D8D63))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: 0x2D8D63).opacity(0.22))
                    .clipShape(Capsule())

                Spacer(minLength: 8)

                Text(dailyPriceText)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            Text(validityLineText)
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

    private var subscriptionTitleText: String {
        let packageName = model.packageItems.first?.title ?? "Basic"
        return "codex \(packageName) 订阅"
    }

    private var remainingDaysBadgeText: String {
        if let badge = model.packageItems.first?.badgeText, !badge.isEmpty {
            return badge
        }
        return "93天"
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

    private var validityLineText: String {
        if let subtitle = model.packageItems.first?.subtitle, !subtitle.isEmpty {
            return subtitle
        }
        return "到期 \(model.renewalValue) · 剩余 \(remainingDaysBadgeText)"
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
                VStack(spacing: 0) {
                    ForEach(panel.records, id: \.id) { item in
                        usageRecordRow(item)
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

    private var usageRecordsTableHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            usageHeaderTitle("时间")
                .frame(width: 170, alignment: .leading)
            usageHeaderTitle("模型")
                .frame(width: 130, alignment: .leading)
            usageHeaderTitle("Tokens")
                .frame(minWidth: 170, alignment: .leading)
            usageHeaderTitle("费用")
                .frame(minWidth: 180, alignment: .leading)
            usageHeaderTitle("明细")
                .frame(width: 52, alignment: .trailing)
        }
    }

    private func usageHeaderTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func usageRecordRow(_ item: CodexUsageRecordViewModel) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.timestampText)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 170, alignment: .leading)

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
            .frame(width: 130, alignment: .leading)

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
            .frame(minWidth: 170, alignment: .leading)

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
            .frame(minWidth: 180, alignment: .leading)

            Button(action: {
                if let detailURL = item.detailURL, !detailURL.isEmpty {
                    onOpenUsageLogDetail?(detailURL)
                } else {
                    onOpenDashboard?()
                }
            }) {
                Text("明细")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x57BF71))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: 0x57BF71).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(width: 52, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func usageLogsCountBadge(panel: CodexUsageRecordsPanelViewModel) -> some View {
        let resolvedCount = panel.totalCount ?? panel.records.count
        if resolvedCount > 0 {
            Text("共 \(resolvedCount.formatted()) 条")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0x57BF71))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(hex: 0x57BF71).opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        .foregroundStyle(pageNumber == page ? Color.white : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .fill(pageNumber == page ? Color(hex: 0x57BF71) : Color.clear)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .stroke(separatorColor, lineWidth: pageNumber == page ? 0 : 0.8)
                        }
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

struct GlassCapsuleModifier: ViewModifier {
    let glassNamespace: Namespace.ID
    let id: String

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
                .glassEffect()
                .glassEffectID(id, in: glassNamespace)
        } else {
            content
                .liquidGlassCapsule()
        }
        #else
        content
            .liquidGlassCapsule()
        #endif
    }
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
    var onSelectStatisticsMode: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSelectSource: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSetAPIKey: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSetAGIKey: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSetInterval: (() -> Void)? {
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
    var onConfigureMCP: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onConfigureStatusColor: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onQuit: (() -> Void)? {
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
                onSetAGIKey: nil,
                onSetInterval: nil,
                onOpenDashboard: nil,
                onOpenPricing: nil,
                onSelectDisplayStyle: nil,
                onToggleSourceGroup: nil,
                onToggleLaunchAtLogin: nil,
                onConfigureMCP: nil,
                onConfigureStatusColor: nil,
                onQuit: nil,
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
            onSetAGIKey: onSetAGIKey,
            onSetInterval: onSetInterval,
            onOpenDashboard: onOpenDashboard,
            onOpenPricing: onOpenPricing,
            onSelectDisplayStyle: onSelectDisplayStyle,
            onToggleSourceGroup: onToggleSourceGroup,
            onToggleLaunchAtLogin: onToggleLaunchAtLogin,
            onConfigureMCP: onConfigureMCP,
            onConfigureStatusColor: onConfigureStatusColor,
            onQuit: onQuit,
            onSelectUsageLogsPage: onSelectUsageLogsPage,
            onOpenUsageLogDetail: onOpenUsageLogDetail
        )
        layoutSubtreeIfNeeded()
        invalidateIntrinsicContentSize()
    }
}
