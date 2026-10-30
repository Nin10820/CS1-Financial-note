import Foundation

/// Money going out (spent) or coming in (received).
nonisolated enum Flow: String, Codable, Sendable, CaseIterable {
    case out
    case `in`
}

/// The six categories from `src/lib/store.ts`, in the same order.
nonisolated enum Category: String, Codable, Sendable, CaseIterable {
    case food = "Food"
    case transport = "Transport"
    case shopping = "Shopping"
    case bills = "Bills"
    case received = "Received"
    case other = "Other"

    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .shopping: "bag.fill"
        case .bills: "doc.text.fill"
        case .received: "arrow.down.circle.fill"
        case .other: "square.grid.2x2.fill"
        }
    }
}

nonisolated enum BillKind: String, Codable, Sendable, CaseIterable {
    case recurring
    case installment
    case oneoff
}

/// Tile icons for bills (Phosphor names in the web app → SF Symbols here).
nonisolated enum BillIcon: String, Codable, Sendable, CaseIterable {
    case house
    case drop
    case gasPump = "gas-pump"
    case lightning
    case phone
    case student
    case monitor
    case bell

    var symbol: String {
        switch self {
        case .house: "house.fill"
        case .drop: "drop.fill"
        case .gasPump: "fuelpump.fill"
        case .lightning: "bolt.fill"
        case .phone: "iphone"
        case .student: "graduationcap.fill"
        case .monitor: "laptopcomputer"
        case .bell: "bell.fill"
        }
    }
}

/// The four asset groups from Figma High Fi 2 › Asset (943:25860).
nonisolated enum AssetKind: String, Codable, Sendable, CaseIterable {
    case available
    case growing
    case aside
    case owed

    var label: String {
        switch self {
        case .available: "Available"
        case .growing: "Growing"
        case .aside: "Set aside"
        case .owed: "Owed"
        }
    }
}

nonisolated enum AssetIcon: String, Codable, Sendable, CaseIterable {
    case gold
    case fund
    case bank
    case cash
    case lent

    /// Short mark drawn on the history tile.
    var mark: String {
        switch self {
        case .gold: "Au"
        case .fund: "fm"
        case .bank: "TP"
        case .cash: "₫"
        case .lent: "→"
        }
    }
}
