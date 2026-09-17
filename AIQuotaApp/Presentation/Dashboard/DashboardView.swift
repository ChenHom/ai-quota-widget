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

                        // 一個 provider 一落牌。多帳號時卡片疊在同一個位置，按一下換下一個帳號
                        ForEach(viewModel.displayState.providerStacks) { stack in
                            ProviderStackCardView(stack: stack)
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
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("AI USAGE")
                    .font(.caption2.weight(.bold))
                    .tracking(1)

                Spacer(minLength: 8)

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                Text("最後同步：\(viewModel.displayState.lastSyncTimeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                // 建置識別：分辨手機上跑的到底是哪一版
                Text(AppConfiguration.commitLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
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

// MARK: - Provider Stack Card

/// 多帳號 provider 疊成一落牌：按下去整落沉到同一個位置，放開彈回時已經換成下一個帳號。
/// 交換就藏在收斂到同一個位置的那一刻，這是整個做法的關鍵。單帳號時退化成一張普通卡片。
struct ProviderStackCardView: View {
    let stack: ProviderStackDisplayState

    /// 記帳號名稱而非索引：快照刷新後伺服器可能重排陣列，使用者看的要還是同一個帳號
    @State private var frontAccount: String?
    /// 整落牌正在被壓住
    @State private var isPressing = false
    /// 按下去的時刻，用來算還要不要補足 pressDuration
    @State private var pressStartedAt: Date?

    /// 後面那張往下露出的高度
    private static let peek: CGFloat = 9
    /// 每往後一層縮小的比例
    private static let shrink: CGFloat = 0.045
    /// 疊超過兩層就不再往下推，避免越堆越糊
    private static let maxVisibleDepth = 2
    /// 壓下去的時間。放開得太快時會補足剩下的，確保交換仍然被壓到底那一刻蓋住
    private static let pressDuration: TimeInterval = 0.13
    /// 按下去時整落牌往中間收斂的位置（0 = 最前面，1 = 牌底那張）。
    /// 所有卡片收到同一個位置、大小與明度，誰在前誰在後完全看不出來
    private static let pressLevel: CGFloat = 0.5
    /// 手指移動超過這個距離就不算點擊，視為捲動
    private static let tapSlop: CGFloat = 10

    var body: some View {
        cardStack
            .contentShape(Rectangle())
            .modifier(
                StackPressGestures(
                    enabled: stack.isMultiAccount,
                    onChanged: dragChanged,
                    onEnded: dragEnded
                )
            )
            .accessibilityElement(children: .contain)
            .accessibilityActions {
                if stack.isMultiAccount {
                    Button("切換下一個帳號") { switchAccountDirectly() }
                }
            }
    }

    private var cardStack: some View {
        let ordered = stack.ordered(from: frontAccount)
        let activeIndex = stack.index(of: frontAccount)

        return ZStack {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { depth, provider in
                let level = isPressing
                    ? Self.pressLevel
                    : CGFloat(min(depth, Self.maxVisibleDepth))
                ProviderCardView(
                    provider: provider,
                    activeIndex: activeIndex,
                    // 疊在後面的卡片不該吃到點擊：重置券徽章是個 Button，
                    // 蓋在下面仍會搶走最前面那張的觸控
                    isInteractive: depth == 0
                )
                .offset(y: level * Self.peek)
                .scaleEffect(1 - level * Self.shrink)
                .opacity(isPressing ? 0.8 : (depth == 0 ? 1 : 0.5))
                .zIndex(Double(ordered.count - depth))
            }
        }
        // 露出的那一角要留空間，否則會被下一張卡蓋掉
        .padding(.bottom, stack.isMultiAccount ? Self.peek : 0)
    }

    // MARK: - 按壓

    private func moved(_ value: DragGesture.Value) -> CGFloat {
        abs(value.translation.width) + abs(value.translation.height)
    }

    /// 手指按著：沉下去。一旦移動超過 tapSlop 就當成捲動，立刻還原
    private func dragChanged(_ value: DragGesture.Value) {
        guard moved(value) <= Self.tapSlop else {
            if isPressing { settle(next: nil) }
            return
        }
        guard !isPressing else { return }
        pressStartedAt = .now
        // 加速壓下去，像被指頭按住
        withAnimation(.easeIn(duration: Self.pressDuration)) { isPressing = true }
    }

    /// 手指離開：彈回來。位移夠小才算點擊，才換帳號
    private func dragEnded(_ value: DragGesture.Value) {
        guard isPressing else { return }
        let next = moved(value) <= Self.tapSlop ? stack.account(after: frontAccount) : nil

        // 點得太快時沉下去還沒走完，先補足剩下的時間。
        // 沒補的話兩張卡還沒收斂到同一個位置就交換，會被看見
        let elapsed = pressStartedAt.map { Date.now.timeIntervalSince($0) } ?? Self.pressDuration
        let remaining = Self.pressDuration - elapsed
        guard remaining > 0 else { return settle(next: next) }

        // next 先算好帶進 closure，不在 closure 裡讀 @State
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            settle(next: next)
        }
    }

    private func settle(next: String?) {
        // 阻尼壓低才彈得出來
        withAnimation(.spring(response: 0.40, dampingFraction: 0.60)) {
            if let next { frontAccount = next }
            isPressing = false
        }
        pressStartedAt = nil
    }

    /// VoiceOver 的自訂動作：沒有按壓動畫可言，直接換
    private func switchAccountDirectly() {
        guard let next = stack.account(after: frontAccount) else { return }
        withAnimation(.spring(response: 0.40, dampingFraction: 0.60)) {
            frontAccount = next
        }
    }
}

/// 疊牌的按壓手勢。
///
/// 刻意不把整張卡包成 `Button`，有兩個 iOS 才有的理由：
/// 1. 卡片裡的重置券徽章本身是 `Button`，巢狀 Button 在 iOS 收不到點擊。
/// 2. `Button` 的 `isPressed` 在捲動把手勢帶走時同樣會轉 false，分不出
///    「放開」與「取消」，捲過多帳號卡片就會誤換帳號。
///
/// 只用一個 `DragGesture`：沉下去／彈回來的動畫走它，是不是點擊則看
/// `translation` 的位移量。之前拿 `onTapGesture` 搭 `DragGesture(minimumDistance: 0)`
/// 判斷點擊是錯的 — 兩個手勢會互搶，tap 根本沒被辨識到，所以卡片只沉不換。
private struct StackPressGestures: ViewModifier {
    let enabled: Bool
    let onChanged: (DragGesture.Value) -> Void
    let onEnded: (DragGesture.Value) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(onChanged)
                    .onEnded(onEnded)
            )
        } else {
            content
        }
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
    /// 目前看的是第幾個帳號，供指示點標示
    var activeIndex: Int = 0
    /// 疊在後面的卡片設為 false，避免蓋住最前面那張的觸控
    var isInteractive: Bool = true

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

                if provider.accountCount > 1 {
                    AccountDots(count: provider.accountCount, activeIndex: activeIndex)
                }

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
        .allowsHitTesting(isInteractive)
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

// MARK: - Account Dots

/// 目前看的是第幾個帳號。
/// 只靠明暗差在 4pt 的小圓點上看不出來（macOS 端實測），現用的是拉長的膠囊：
/// 形狀差在任何尺寸都讀得到。
private struct AccountDots: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { index in
                let isActive = index == activeIndex
                Capsule()
                    .fill(Color.primary.opacity(isActive ? 0.85 : 0.22))
                    .frame(width: isActive ? 10 : 4, height: 4)
            }
        }
        .accessibilityHidden(true)
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
                .frame(width: 22, alignment: .leading)
                .font(.caption2.weight(.semibold))

            ProgressBarView(
                progress: (window.remainingPercent ?? 0) / 100.0,
                color: barColor(window.remainingPercent)
            )
            .frame(maxWidth: .infinity)

            Text(window.percentText)
                .frame(width: 36, alignment: .trailing)
                .font(.caption2.weight(.bold))
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(window.resetsAtRowText)
                .frame(width: 104, alignment: .trailing)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        // 這三欄的字級上限壓在預設值：它們是固定欄寬的表格，跟著動態字體長大就會
        // 折行（實機上「100%」被折成兩行、重置時間折成兩行）。Provider 名稱、
        // 狀態與標頭仍然完整支援動態字體
        .dynamicTypeSize(...DynamicTypeSize.large)
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
