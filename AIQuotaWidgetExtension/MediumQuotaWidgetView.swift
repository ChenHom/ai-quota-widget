import SwiftUI
import WidgetKit

struct MediumQuotaWidgetView: View {
    let entry: QuotaEntry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(entry.displayState.freshness == .fresh ? SemanticColor.green.color : .secondary)
                    
                    Text("AI QUOTA")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 新鮮度視覺與文字標記
                freshnessIndicator(entry.displayState.freshness)
            }
            
            // 3個 Provider 的列表。
            // 刻意只取預設帳號：systemMedium 的垂直空間放不下第四列，
            // 多帳號要怎麼在 Widget 呈現尚未定案（App Dashboard 已顯示所有帳號）
            VStack(spacing: 10) {
                ForEach(entry.displayState.defaultAccountProviders) { provider in
                    providerRow(provider)
                }
            }
        }
        .padding(.horizontal, 4)
        .widgetURL(URL(string: "aiquota://dashboard")) // 支援點擊深層連結
    }
    
    private func freshnessIndicator(_ state: FreshnessState) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(freshnessColor(state))
                .frame(width: 6, height: 6)
            
            Text(freshnessText(state))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(freshnessColor(state).opacity(0.08))
        )
    }
    
    private func freshnessColor(_ state: FreshnessState) -> Color {
        switch state {
        case .fresh: return SemanticColor.green.color
        case .delayed: return SemanticColor.orange.color
        case .stale: return SemanticColor.red.color
        case .unavailable: return SemanticColor.gray.color
        }
    }
    
    private func freshnessText(_ state: FreshnessState) -> String {
        switch state {
        case .fresh: return "已同步"
        case .delayed: return "延遲"
        case .stale: return "過期"
        case .unavailable: return "無資料"
        }
    }
    
    private func providerRow(_ provider: ProviderDisplayState) -> some View {
        HStack(spacing: 10) { // 稍微縮減 spacing，為進度條與名稱爭取更多空間
            // Provider Name - 固定字級（不隨動態字體放大，與同列 5h/7d、百分比一致），
            // 超出欄寬時以 minimumScaleFactor 縮小而非折行。
            // 欄寬 66pt 是為了容納重置券徽章：每列都留同樣的寬度，沒有券的列
            // 才不會讓三列的進度條對不齊
            HStack(spacing: 3) {
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Widget 不能開 popover，徽章只顯示張數；到期時間要進 App 才看得到
                if let credits = provider.resetCredits {
                    Text(credits.badgeText)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.18), in: Capsule())
                        .widgetAccentable()
                }
            }
            .frame(width: 66, alignment: .leading)
            
            // 5 Hours Quota Bar
            HStack(spacing: 4) {
                Text("5h")
                    .font(.system(size: 8, weight: .bold)) // 稍微調小 5h 字樣以節省空間
                    .foregroundStyle(.secondary)
                
                if let pct = provider.fiveHour.remainingPercent {
                    ProgressBarView(progress: pct / 100.0, color: barColor(pct))
                        .widgetAccentable() // 支援 Tinted 模式下變色
                } else {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 5)
                }
                
                Text(provider.fiveHour.percentText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .frame(width: 28, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            
            // 7 Days Quota Bar
            HStack(spacing: 4) {
                Text("7d")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                
                if let pct = provider.sevenDay.remainingPercent {
                    ProgressBarView(progress: pct / 100.0, color: barColor(pct))
                        .widgetAccentable()
                } else {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 5)
                }
                
                Text(provider.sevenDay.percentText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .frame(width: 28, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
        }
        .accessibilityLabel(provider.voiceOverLabel)
    }
    
    private func barColor(_ percent: Double) -> Color {
        if percent > 50 { return SemanticColor.green.color }
        if percent > 20 { return SemanticColor.orange.color }
        return SemanticColor.red.color
    }
}

#Preview(as: .systemMedium) {
    AIQuotaWidget()
} timeline: {
    QuotaEntry.mockEntry
    QuotaEntry.mockDelayedEntry
    QuotaEntry.mockStaleEntry
    QuotaEntry.mockEmptyEntry
}
