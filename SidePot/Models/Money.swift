import Foundation

struct Money: Codable, Hashable, Comparable {
    var cents: Int

    init(cents: Int) { self.cents = max(0, cents) }

    static func < (lhs: Money, rhs: Money) -> Bool { lhs.cents < rhs.cents }

    var dollarsString: String {
        let d = Double(cents) / 100.0
        return String(format: "$%.2f", d)
    }

    static var zero: Money { Money(cents: 0) }
}
