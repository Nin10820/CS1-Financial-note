import XCTest
@testable import FinancialNote

@MainActor
final class AssetMathTests: XCTestCase {
    func testSampleHoldingsAddUp() {
        let x = SampleData.make(today: "2026-10-28")
        let s = AssetMath.shares(x.assets)
        XCTAssertEqual(s.total, 287_465_000)
        XCTAssertEqual(s.groups.reduce(0) { $0 + $1.pct }, 100)
        // Every sample asset keeps its moves: put in, then what it's worth now.
        let gold = x.assets.first { $0.name == "Gold" }!
        let g = AssetMath.growth(gold, moves: x.moves)
        XCTAssertEqual(g?.putIn, 30_000_000)
        XCTAssertEqual(g?.change, 35_000_000)
    }

    func testSharesAlwaysAddUpToHundred() {
        let assets = [
            Asset(name: "A", kind: .available, icon: .cash, amount: 1, updated: "2026-10-28"),
            Asset(name: "B", kind: .growing, icon: .gold, amount: 1, updated: "2026-10-28"),
            Asset(name: "C", kind: .aside, icon: .bank, amount: 1, updated: "2026-10-28"),
        ]
        let s = AssetMath.shares(assets)
        XCTAssertEqual(s.groups.reduce(0) { $0 + $1.pct }, 100)
        XCTAssertEqual(s.groups.map(\.pct), [34, 33, 33, 0])
    }

    func testNoAssetsMeansZeroEverywhere() {
        XCTAssertEqual(AssetMath.shares([]).groups.map(\.pct), [0, 0, 0, 0])
    }

    func testGuessIcon() {
        XCTAssertEqual(AssetMath.guessIcon("Vàng SJC", kind: .growing), .gold)
        XCTAssertEqual(AssetMath.guessIcon("Quỹ VN30", kind: .growing), .fund)
        XCTAssertEqual(AssetMath.guessIcon("Tiết kiệm", kind: .aside), .bank)
        XCTAssertEqual(AssetMath.guessIcon("Cho Lan mượn", kind: .owed), .lent)
        XCTAssertEqual(AssetMath.guessIcon("Ví", kind: .available), .cash)
    }
}
