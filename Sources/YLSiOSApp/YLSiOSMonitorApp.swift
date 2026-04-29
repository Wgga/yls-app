import SwiftUI
import YLSShared
import YLSSharedUI

public struct YLSiOSMonitorAppRoot: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            YLSiOSMonitorRootView()
        }
    }
}

@MainActor
public final class YLSiOSMonitorViewModel: ObservableObject {
    @Published public private(set) var summary: StatusSummaryViewModel = .placeholder

    private let store: CodexMonitorStore

    public init(store: CodexMonitorStore = CodexMonitorStore()) {
        self.store = store
        self.store.onStateChange = { [weak self] in
            self?.syncSummary()
        }
        self.store.loadConfiguration()
        self.store.initializeStatusFallback()
        self.store.refreshNow()
        syncSummary()
    }

    public func togglePanelMode() {
        store.togglePanelMode()
    }

    public func toggleEmailVisibility() {
        store.toggleEmailVisibility()
    }

    public func refresh() {
        store.refreshNow()
    }

    public func selectStatisticsMode(_ mode: StatisticsDisplayMode) {
        store.selectStatisticsDisplayMode(mode)
    }

    public func selectSource(_ source: PackageSource) {
        store.selectSource(source)
    }

    public func setAPIKey(_ value: String, for source: PackageSource) {
        store.setAPIKey(value, for: source)
    }

    public func setPollInterval(_ seconds: Double) {
        _ = store.setPollInterval(seconds)
    }

    public func selectDisplayStyle(_ style: StatusDisplayStyle) {
        store.selectDisplayStyle(style)
    }

    public func toggleSourceGroup(_ source: PackageSource) {
        store.toggleSourceGroup(source)
    }

    public func configureMCP(enabled: Bool, port: UInt16) {
        store.setMCPConfiguration(enabled: enabled, port: port)
    }

    public func setStatusBarColor(mode: StatusBarForegroundMode, colorHex: String) {
        store.setStatusBarColor(mode: mode, colorHex: colorHex)
    }

    public func selectUsageLogsPage(_ page: Int) {
        store.selectUsageLogsPage(page)
    }

    public var dashboardURL: URL? {
        switch summary.currentSource {
        case .codex:
            return URL(string: AppMeta.dashboardURL)
        case .agi:
            return nil
        }
    }

    public var pricingURL: URL? {
        switch summary.currentSource {
        case .codex:
            return URL(string: AppMeta.pricingURL)
        case .agi:
            return nil
        }
    }

    private func syncSummary() {
        summary = store.makeSummaryModel(
            supportsLaunchAtLogin: false,
            launchAtLoginUnavailableReason: "iOS 不支持开机自启。",
            mcpStatusText: store.mcpEnabled ? "iOS 已保存配置（不启动本地服务）" : "已关闭"
        )
    }
}

public struct YLSiOSMonitorRootView: View {
    private let desktopCanvasSize = CGSize(width: 1008, height: 647)

    @StateObject private var viewModel = YLSiOSMonitorViewModel()
    @Environment(\.openURL) private var openURL

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                MonitorDashboardShellView(
                    model: viewModel.summary,
                    onTogglePanelMode: { viewModel.togglePanelMode() },
                    onToggleEmail: { viewModel.toggleEmailVisibility() },
                    onRefresh: { viewModel.refresh() },
                    onSelectStatisticsMode: { viewModel.selectStatisticsMode($0) },
                    onSelectSource: { viewModel.selectSource($0) },
                    onSetAPIKey: { source, token in viewModel.setAPIKey(token, for: source) },
                    onSetInterval: { viewModel.setPollInterval($0) },
                    onOpenDashboard: { open(viewModel.dashboardURL) },
                    onOpenPricing: { open(viewModel.pricingURL) },
                    onSelectDisplayStyle: { viewModel.selectDisplayStyle($0) },
                    onToggleSourceGroup: { viewModel.toggleSourceGroup($0) },
                    onToggleLaunchAtLogin: nil,
                    onConfigureMCP: { enabled, port in viewModel.configureMCP(enabled: enabled, port: port) },
                    onSetStatusBarColor: { mode, hex in viewModel.setStatusBarColor(mode: mode, colorHex: hex) },
                    onSelectUsageLogsPage: { viewModel.selectUsageLogsPage($0) },
                    onOpenUsageLogDetail: { rawURL in open(URL(string: rawURL)) }
                )
                .frame(
                    width: max(desktopCanvasSize.width, proxy.size.width),
                    height: max(desktopCanvasSize.height, proxy.size.height)
                )
            }
            .ignoresSafeArea()
            .background(Color.black)
        }
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }
}
