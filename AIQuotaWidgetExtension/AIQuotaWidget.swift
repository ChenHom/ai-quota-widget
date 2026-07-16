import WidgetKit
import SwiftUI

struct QuotaTimelineProvider: TimelineProvider {
    private let repository = QuotaRepository()
    private let cache = QuotaCache()
    
    /// placeholder 使用匿名範例資料，不讀取私人資料或發出網路請求。
    func placeholder(in context: Context) -> QuotaEntry {
        QuotaEntry.mockEntry
    }

    /// snapshot 優先讀取快取；無快取時使用範例資料。
    func getSnapshot(in context: Context, completion: @escaping (QuotaEntry) -> ()) {
        let now = Date()
        if let cached = cache.load() {
            let state = QuotaDisplayState.map(
                response: cached.quota,
                fetchedAt: cached.fetchedAt,
                now: now
            )
            completion(QuotaEntry(date: now, displayState: state))
        } else {
            completion(QuotaEntry.mockEntry)
        }
    }

    /// timeline 透過 Repository 嘗試取得最新資料。
    /// 產生單一 entry，refresh policy 為 .after(now + 30 minutes)。
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaEntry>) -> ()) {
        Task {
            let now = Date()
            let result = await repository.latestQuota()
            
            let state: QuotaDisplayState
            switch result {
            case .fresh(let cached):
                state = QuotaDisplayState.map(
                    response: cached.quota,
                    fetchedAt: cached.fetchedAt,
                    now: now
                )
            case .cached(let cached, _):
                state = QuotaDisplayState.map(
                    response: cached.quota,
                    fetchedAt: cached.fetchedAt,
                    now: now
                )
            case .unavailable:
                state = QuotaDisplayState.map(response: nil, fetchedAt: nil, now: now)
            }
            
            let entry = QuotaEntry(date: now, displayState: state)
            let refreshDate = now.addingTimeInterval(30 * 60) // 30 分鐘後
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct AIQuotaWidgetEntryView : View {
    var entry: QuotaEntry

    var body: some View {
        MediumQuotaWidgetView(entry: entry)
    }
}

@main
struct AIQuotaWidget: Widget {
    let kind: String = "AIQuotaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuotaTimelineProvider()) { entry in
            AIQuotaWidgetEntryView(entry: entry)
                .containerBackground(.ultraThinMaterial, for: .widget)
        }
        .configurationDisplayName("AI Quota")
        .description("快速查看 AI 額度剩餘百分比。")
        .supportedFamilies([.systemMedium])
    }
}
