import Foundation

struct SystemClock: Clocking {
    let timeZone: TimeZone

    init(timeZone: TimeZone) {
        self.timeZone = timeZone
    }

    func now() -> Date {
        Date()
    }
}
