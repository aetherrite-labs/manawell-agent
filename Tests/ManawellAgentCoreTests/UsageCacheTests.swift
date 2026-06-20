import Foundation
import Testing
import ManawellCore
@testable import ManawellAgentCore

/// A collector whose output and failure are controllable, for exercising the cache.
private actor StubCollector: UsageCollector {
    nonisolated let providerName: String
    private var result: Result<[UsageSnapshot], any Error>
    private(set) var callCount = 0

    init(providerName: String, result: Result<[UsageSnapshot], any Error>) {
        self.providerName = providerName
        self.result = result
    }

    func set(_ newResult: Result<[UsageSnapshot], any Error>) { result = newResult }
    func calls() -> Int { callCount }

    func collect() async throws -> [UsageSnapshot] {
        callCount += 1
        return try result.get()
    }
}

private struct Boom: Error {}

private func snap(_ name: String, _ pct: Double) -> UsageSnapshot {
    UsageSnapshot(providerName: name, windowLabel: "w", percentUsed: pct, resetsAt: .now, lastUpdated: .now)
}

@Test("Snapshots are merged across collectors and ranked highest-usage first")
func mergesAndRanks() async {
    let a = StubCollector(providerName: "A", result: .success([snap("A", 20)]))
    let b = StubCollector(providerName: "B", result: .success([snap("B", 80)]))
    let cache = UsageCache(collectors: [a, b])
    let result = await cache.snapshots()
    #expect(result.map(\.providerName) == ["B", "A"])
}

@Test("Within the throttle window, collectors are not called again")
func throttleWindow() async {
    let clock = MutableClock()
    let collector = StubCollector(providerName: "A", result: .success([snap("A", 10)]))
    let cache = UsageCache(collectors: [collector], minRefreshInterval: 60, now: clock.now)

    _ = await cache.snapshots()           // cold → fetch
    _ = await cache.snapshots()           // within window → cached
    #expect(await collector.calls() == 1)

    clock.advance(by: 61)
    _ = await cache.snapshots()           // window elapsed → fetch again
    #expect(await collector.calls() == 2)
}

@Test("A failing collector keeps serving the last good snapshots")
func servesStaleOnFailure() async {
    let clock = MutableClock()
    let collector = StubCollector(providerName: "A", result: .success([snap("A", 42)]))
    let cache = UsageCache(collectors: [collector], minRefreshInterval: 60, now: clock.now)

    let first = await cache.snapshots()
    #expect(first.first?.percentUsed == 42)

    await collector.set(.failure(Boom()))
    clock.advance(by: 61)
    let second = await cache.snapshots()
    #expect(second.first?.percentUsed == 42)   // unchanged, not blanked
}

@Test("Cold start with every collector failing falls back to demo data")
func demoFallbackOnColdFailure() async {
    let collector = StubCollector(providerName: "A", result: .failure(Boom()))
    let cache = UsageCache(collectors: [collector])
    let result = await cache.snapshots()
    #expect(!result.isEmpty)
    #expect(result.contains { $0.providerName == "Claude" })   // from DemoUsageProvider
}

/// Test clock whose closure the cache reads for "now".
private final class MutableClock: @unchecked Sendable {
    private var current = Date(timeIntervalSince1970: 1_700_000_000)
    private let lock = NSLock()
    var now: @Sendable () -> Date { { [self] in lock.withLock { current } } }
    func advance(by seconds: TimeInterval) { lock.withLock { current.addTimeInterval(seconds) } }
}
