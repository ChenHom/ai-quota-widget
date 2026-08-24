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
                        // 三個 Provider 卡片
                        ForEach(viewModel.displayState.providers) { provider in
                            ProviderCardView(provider: provider)
                        }
                        
                        if let error = viewModel.errorMessage {
                            errorMessageView(error)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    await viewModel.refresh()
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
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
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
}

// MARK: - Provider Card View

struct ProviderCardView: View {
    let provider: ProviderDisplayState
    @State private var showingResetCredits = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片頂部
            HStack {
                Text(provider.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                
                if let credits = provider.resetCredits {
                    resetCreditsBadge(credits)
                }
                
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
                    Text("更新時間：\(formatDate(lastSuccess))")
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
    
    // 重置券只顯示張數徽章，點擊才展開到期清單，避免卡片高度隨券數浮動
    private func resetCreditsBadge(_ credits: ResetCreditsDisplayState) -> some View {
        Button {
            showingResetCredits = true
        } label: {
            Text(credits.badgeText)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("重置券 \(credits.availableCount) 張，點兩下查看到期時間")
        .popover(isPresented: $showingResetCredits) {
            VStack(alignment: .leading, spacing: 6) {
                Text("重置券到期時間")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                ForEach(Array(credits.expiryTexts.enumerated()), id: \.offset) { _, text in
                    Text(text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
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
