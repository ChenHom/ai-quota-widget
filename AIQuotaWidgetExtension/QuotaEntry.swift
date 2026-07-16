import WidgetKit
import Foundation

struct QuotaEntry: TimelineEntry {
    let date: Date
    let displayState: QuotaDisplayState
    
    // 用於 Preview 與 Placeholder
    static var mockEntry: QuotaEntry {
        let now = Date()
        let state = QuotaDisplayState.map(response: MockData.normalQuota, fetchedAt: now, now: now)
        return QuotaEntry(date: now, displayState: state)
    }
    
    static var mockDelayedEntry: QuotaEntry {
        let now = Date()
        let state = QuotaDisplayState.map(response: MockData.delayedQuota, fetchedAt: now.addingTimeInterval(-1800), now: now)
        return QuotaEntry(date: now, displayState: state)
    }
    
    static var mockStaleEntry: QuotaEntry {
        let now = Date()
        let state = QuotaDisplayState.map(response: MockData.staleQuota, fetchedAt: now.addingTimeInterval(-7200), now: now)
        return QuotaEntry(date: now, displayState: state)
    }
    
    static var mockEmptyEntry: QuotaEntry {
        let now = Date()
        let state = QuotaDisplayState.map(response: nil, fetchedAt: nil, now: now)
        return QuotaEntry(date: now, displayState: state)
    }
}
