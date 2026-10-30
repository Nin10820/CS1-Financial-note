import XCTest
@testable import FinancialNote

final class VietQRTests: XCTestCase {
    /// Builds "IDLLvalue" so the test codes always have correct lengths.
    private func tlv(_ id: String, _ value: String) -> String {
        id + String(format: "%02d", value.count) + value
    }

    private func code(amount: String? = "50000", name: String? = nil, note: String? = "Com trua") -> String {
        let bene = tlv("00", "970436") + tlv("01", "1234567890123")
        let acc = tlv("00", "A000000727") + tlv("01", bene) + tlv("02", "QRIBFTTA")
        var s = tlv("00", "01") + tlv("01", "12") + tlv("38", acc) + tlv("53", "704")
        if let amount { s += tlv("54", amount) }
        s += tlv("58", "VN")
        if let name { s += tlv("59", name) }
        if let note { s += tlv("62", tlv("08", note)) }
        return s + "6304ABCD"
    }

    func testReadsAmountBankAndNote() {
        let q = VietQR(payload: code())
        XCTAssertEqual(q?.amount, 50_000)
        XCTAssertEqual(q?.bankName, "Vietcombank")
        XCTAssertEqual(q?.account, "1234567890123")
        XCTAssertEqual(q?.note, "Com trua")
        XCTAssertEqual(q?.title, "Com trua")
    }

    func testShopNameWhenThereIsNoNote() {
        let q = VietQR(payload: code(amount: nil, name: "PHUC LONG COFFEE", note: nil))
        XCTAssertNil(q?.amount)
        XCTAssertEqual(q?.title, "Phuc Long Coffee")
    }

    func testBankWhenThereIsNothingElse() {
        XCTAssertEqual(VietQR(payload: code(amount: "120000", note: nil))?.title, "Transfer to Vietcombank")
    }

    func testNotAPaymentCode() {
        XCTAssertNil(VietQR(payload: "https://example.com"))
        XCTAssertNil(VietQR(payload: "WIFI:S:home;T:WPA;P:secret;;"))
        XCTAssertNil(VietQR(payload: "000201010211999"))
    }

    func testScannedTextBecomesLines() {
        let lines = ScanText.lines(from: ["  CƠM TẤM  35.000 ", "", "Trà đá 5.000", "   "])
        XCTAssertEqual(lines, ["CƠM TẤM 35.000", "Trà đá 5.000"])
        // The note reader then reads them like anything typed.
        let d = NoteParser.parse(lines.joined(separator: "\n"), day: "2026-10-30")
        XCTAssertEqual(d.map(\.amount), [35_000, 5_000])
    }
}
