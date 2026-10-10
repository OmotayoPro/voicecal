import Testing
@testable import Voicecal

struct KeypadLayoutTests {
    @Test func hasFiveRowsOfFourKeys() {
        #expect(KeypadKey.layout.count == 5)
        #expect(KeypadKey.layout.allSatisfy { $0.count == 4 })
    }

    @Test func everyDigitAppearsExactlyOnce() {
        let keys = KeypadKey.layout.flatMap { $0 }
        for digit in 0 ... 9 {
            #expect(keys.filter { $0 == .digit(digit) }.count == 1)
        }
    }

    @Test func noKeyIsDuplicated() {
        let keys = KeypadKey.layout.flatMap { $0 }
        #expect(Set(keys).count == keys.count)
    }
}
