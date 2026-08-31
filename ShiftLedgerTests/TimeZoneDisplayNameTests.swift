import Foundation
import Testing
@testable import ShiftLedger

struct TimeZoneDisplayNameTests {
    @Test("Europe/Stockholm отображается по-русски")
    func stockholmRussian() {
        #expect(TimeZoneDisplayName.value(for: "Europe/Stockholm", locale: Locale(identifier: "ru_RU")) == "Стокгольм")
    }

    @Test("Europe/Stockholm отображается по-английски")
    func stockholmEnglish() {
        #expect(TimeZoneDisplayName.value(for: "Europe/Stockholm", locale: Locale(identifier: "en_US")) == "Stockholm")
    }

    @Test("UTC сохраняет стабильный fallback")
    func utcFallback() {
        #expect(TimeZoneDisplayName.value(for: "UTC", locale: Locale(identifier: "en_US")) == "UTC")
    }

    @Test("Europe/Paris использует exemplar city Foundation")
    func parisUsesExemplarCity() {
        let value = TimeZoneDisplayName.value(for: "Europe/Paris", locale: Locale(identifier: "en_US"))

        #expect(value.isEmpty == false)
        #expect(value != "Europe/Paris")
    }
}
