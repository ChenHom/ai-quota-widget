import Foundation

public protocol ClockProtocol: Sendable {
    var now: Date { get }
}

public struct SystemClock: ClockProtocol {
    public init() {}
    public var now: Date { Date() }
}

public struct CustomClock: ClockProtocol {
    public let fixedDate: Date
    
    public init(fixedDate: Date) {
        self.fixedDate = fixedDate
    }
    
    public var now: Date { fixedDate }
}
