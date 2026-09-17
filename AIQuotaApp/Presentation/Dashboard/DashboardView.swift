import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 卡片用 .secondarySystemGroupedBackground（淺色模式為白），
                // 底色就必須是 .systemGroupedBackground 才有對比。
                // 原本的漸層頂端是 .systemBackground，淺色模式下同樣是白色，
                // 配上這次移除陰影後（與 macOS 端一致，陰影套在島上會變黑方塊）
                // 螢幕上方的卡片會整個融進背景看不見
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    // 卡片間距與 macOS 端的面板一致（10pt）
                    VStack(spacing: 10) {
                        headerCard

                        if let error = viewModel.errorMessage {
                            errorMessageView(error)
                        }

                        // 一個帳號一張卡片。schema v2 起 claude 可能同時有 main 與 work，
                        // Dashboard 是 ScrollView，沒有 Widget 那種固定列數的限制
                        ForEach(viewModel.displayState.providers) { provider in
                            ProviderCardView(provider: provider)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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
                    .accessibilityLabel("設定")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Header

    /// 對應 macOS 端的標頭島：左側標題與最後同步時間。
    /// macOS 的重新整理按鈕在 iOS 由下拉重新整理取代，這裡只在載入時顯示轉圈。
    private var headerCard: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI USAGE")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                Text("最後同步：\(viewModel.displayState.lastSyncTimeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private func errorMessageView(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SemanticColor.red.color)
            Text(msg)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SemanticColor.red.color.opacity(0.08))
        )
    }
}

// MARK: - Provider Card View

/// 版面對應 macOS 端的 `ProviderCard`：名稱列 + 5h／7d 兩條橫向進度列。
/// 差別只有進度列用語意色而非白色 — macOS 的白色是為了讓玻璃島在任意桌布上都可讀，
/// iOS 卡片是實心底色，白色進度列會看不見，且色階與 Widget 一致。
struct ProviderCardView: View {
    /// 多帳號時用底色區分帳號，色相與 macOS 端相同。
    /// 第一個帳號（一般是 main）不上色，維持與單帳號卡片相同的外觀
    private static let accountTints: [Color] = [
        Color(red: 0.58, green: 0.47, blue: 1.00),   // 紫
        Color(red: 0.27, green: 0.78, blue: 0.78),   // 青
        Color(red: 1.00, green: 0.47, blue: 0.74)    // 粉
    ]

    let provider: ProviderDisplayState
    @State private var showingResetCredits = false

    private var tint: Color? {
        guard provider.accountCount > 1, provider.accountIndex > 0 else { return nil }
        return Self.accountTints[(provider.accountIndex - 1) % Self.accountTints.count]
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(provider.displayName)
                    .font(.headline)
                    .fontDesign(.rounded)

                if let accountLabel = provider.accountLabel {
                    accountTag(accountLabel)
                }

                if let credits = provider.resetCredits {
                    resetCreditsBadge(credits)
                }

                Spacer(minLength: 4)

                // 「更新時間：」前綴拿掉只留時間 — 標頭的「最後同步」已經交代時間的意思
                Text(provider.lastSuccessTimeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                statusBadge(provider.status)
            }

            UsageRowView(label: "5h", window: provider.fiveHour)
            UsageRowView(label: "7d", window: provider.sevenDay)
        }
        .padding(12)
        .background(cardBackground)
        // 不用 .combine：重置券徽章是個按鈕，合併後就不再是獨立可觸達的控制項
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        ZStack {
            shape.fill(Color(.secondarySystemGroupedBackground))
            if let tint {
                shape.fill(tint.opacity(0.12))
                shape.stroke(tint.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private func accountTag(_ label: String) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((tint ?? .secondary).opacity(0.22), in: Capsule())
    }

    // 重置券只顯示張數徽章，點擊才展開到期清單，避免卡片高度隨券數浮動
    private func resetCreditsBadge(_ credits: ResetCreditsDisplayState) -> some View {
        Button {
            showingResetCredits = true
        } label: {
            Text(credits.badgeText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor.opacity(0.18)))
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

    private func statusBadge(_ status: ProviderStatus) -> some View {
        Text(status.displayText)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(status.semanticColor.color.opacity(0.25), in: Capsule())
    }
}

// MARK: - Usage Row

/// 對應 macOS 端的 `UsageRow`：欄寬固定，四欄依序是標籤、進度列、百分比、重置時間。
struct UsageRowView: View {
    let label: String
    let window: WindowDisplayState

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 24, alignment: .leading)
                .font(.caption.weight(.semibold))

            ProgressBarView(
                progress: (window.remainingPercent ?? 0) / 100.0,
                color: barColor(window.remainingPercent)
            )
            .frame(maxWidth: .infinity)

            Text(window.percentText)
                .frame(width: 38, alignment: .trailing)
                .font(.caption.weight(.bold))
                .fontDesign(.rounded)

            Text(window.resetsAtRowText)
                .frame(width: 116, alignment: .trailing)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        // 併成一個元素，但要自己給 label／value，否則 VoiceOver 會整列跳過
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue("\(window.percentVoiceOverText)，重置時間 \(window.resetsAtVoiceOverText)")
    }

    private var accessibilityTitle: String {
        label == "5h" ? "5 小時額度" : "7 天額度"
    }

    private func barColor(_ percent: Double?) -> Color {
        guard let pct = percent else { return SemanticColor.gray.color }
        if pct > 50 { return SemanticColor.green.color }
        if pct > 20 { return SemanticColor.orange.color }
        return SemanticColor.red.color
    }
}

#Preview("正常") {
    let vm = AppViewModel()
    vm.loadMockData(.normal)
    return DashboardView(viewModel: vm)
}

#Preview("無資料") {
    DashboardView(viewModel: AppViewModel())
}
