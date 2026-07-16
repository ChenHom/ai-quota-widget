import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景漸層
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 頂部新鮮度標示與同步狀態
                        freshnessHeaderSection
                        
                        // 三個 Provider 卡片
                        ForEach(viewModel.displayState.providers) { provider in
                            ProviderCardView(provider: provider)
                        }
                        
                        if let error = viewModel.errorMessage {
                            errorMessageView(error)
                        }
                        
                        // 底部手動重新整理按鈕
                        refreshButton
                            .padding(.top, 10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("AI Quota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary)
                    }
                }
                
                // 為了展示方便，在 toolbar 放一個 Mock 切換按鈕
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("正常狀態 (Fresh)") { viewModel.loadMockData(.normal) }
                        Button("同步延遲 (Delayed)") { viewModel.loadMockData(.delayed) }
                        Button("資料過期 (Stale)") { viewModel.loadMockData(.stale) }
                        Button("網路失敗 (Error)") { viewModel.loadMockData(.unavailable) }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
        }
    }
    
    private var freshnessHeaderSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(freshnessIndicatorColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: freshnessIndicatorColor.opacity(0.5), radius: 4)
                    
                    Text(viewModel.displayState.freshness.displayText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                Text(viewModel.displayState.lastSyncText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        )
    }
    
    private var freshnessIndicatorColor: Color {
        switch viewModel.displayState.freshness {
        case .fresh: return SemanticColor.green.color
        case .delayed: return SemanticColor.orange.color
        case .stale: return SemanticColor.red.color
        case .unavailable: return SemanticColor.gray.color
        }
    }
    
    private func errorMessageView(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SemanticColor.red.color)
            Text(msg)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SemanticColor.red.color.opacity(0.08))
        )
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.refresh()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("手動重新整理")
            }
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.isLoading)
    }
}

// MARK: - Provider Card View

struct ProviderCardView: View {
    let provider: ProviderDisplayState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片頂部
            HStack {
                Text(provider.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                
                Spacer()
                
                // 狀態 Badge
                statusBadge(provider.status)
            }
            
            // 額度視窗百分比 (5h & 7d)
            HStack(spacing: 30) {
                // 5 Hours
                quotaRingView(
                    title: "5 小時額度",
                    percent: provider.fiveHour.remainingPercent,
                    percentText: provider.fiveHour.percentText,
                    resetsAtText: provider.fiveHour.resetsAtText
                )
                
                Spacer()
                
                // 7 Days
                quotaRingView(
                    title: "7 天額度",
                    percent: provider.sevenDay.remainingPercent,
                    percentText: provider.sevenDay.percentText,
                    resetsAtText: provider.sevenDay.resetsAtText
                )
            }
            .padding(.vertical, 4)
            
            // 底部 Provider 本次更新時間
            if let lastSuccess = provider.lastSuccessAt {
                HStack {
                    Spacer()
                    Text("來源更新時間：\(formatDate(lastSuccess))")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.75))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }
    
    @ViewBuilder
    private func statusBadge(_ status: ProviderStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.isNormal ? SemanticColor.green.color : SemanticColor.red.color)
                .frame(width: 6, height: 6)
            
            Text(status.displayText)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(status.isNormal ? SemanticColor.green.color : SemanticColor.red.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(status.isNormal ? SemanticColor.green.color.opacity(0.08) : SemanticColor.red.color.opacity(0.08))
        )
    }
    
    private func quotaRingView(title: String, percent: Double?, percentText: String, resetsAtText: String) -> some View {
        HStack(spacing: 12) {
            ProgressRingView(
                progress: (percent ?? 0.0) / 100.0,
                color: ringColor(percent),
                ringWidth: 6
            )
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(percentText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(resetsAtText == "—" ? "無重置時間" : resetsAtText)
                        .font(.system(size: 8))
                }
                .foregroundStyle(.tertiary)
            }
        }
    }
    
    private func ringColor(_ percent: Double?) -> Color {
        guard let pct = percent else { return SemanticColor.gray.color }
        if pct > 50 { return SemanticColor.green.color }
        if pct > 20 { return SemanticColor.orange.color }
        return SemanticColor.red.color
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    let vm = AppViewModel()
    DashboardView(viewModel: vm)
}
