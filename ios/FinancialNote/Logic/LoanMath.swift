import Foundation

/// Family loans, per person: what came in, what was paid back, the interest so far and what's
/// owed today. Interest is simple, day by day, on what's still borrowed, at the rate of the
/// latest money received (default 6% a year); interest paid comes off the interest first.
enum LoanMath {
    struct Person: Equatable {
        var who: String
        var received: Int
        var paidBack: Int
        var interest: Int
        var interestPaid: Int
        var rate: Double
        /// Borrowed still out, plus interest not yet paid.
        var owed: Int { max(0, received - paidBack) + max(0, interest - interestPaid) }
        var principal: Int { max(0, received - paidBack) }
    }

    static func people(_ loans: [FamilyLoan], today: String) -> [Person] {
        Dictionary(grouping: loans, by: \.who)
            .map { person($0.key, $0.value, today: today) }
            .sorted { $0.owed > $1.owed }
    }

    static func person(_ who: String, _ moves: [FamilyLoan], today: String) -> Person {
        let sorted = moves.filter { $0.date <= today }.sorted { $0.date < $1.date }
        var principal = 0, interest = 0.0, last: String?
        var rate = 6.0
        func accrue(to day: String) {
            if let last {
                let days = Calendar.current.dateComponents([.day], from: Day.date(last), to: Day.date(day)).day ?? 0
                interest += Double(max(0, principal)) * rate / 100 * Double(max(0, days)) / 365
            }
            last = day
        }
        var received = 0, back = 0, paidInterest = 0
        for m in sorted {
            accrue(to: m.date)
            switch m.kind {
            case .received: principal += m.amount; received += m.amount; rate = m.rate
            case .paidBack: principal -= m.amount; back += m.amount
            case .interest: paidInterest += m.amount
            }
        }
        accrue(to: today)
        return Person(who: who, received: received, paidBack: back, interest: Int(interest.rounded()),
                      interestPaid: paidInterest, rate: rate)
    }

    static func owed(_ loans: [FamilyLoan], today: String) -> Int {
        people(loans, today: today).reduce(0) { $0 + $1.owed }
    }
}
