import XCTest

/// Keeps every text on the Figma type scale (see AppFont). Reads the app's Swift sources and
/// fails on any size that isn't on the scale, naming the file and line.
final class TypeScaleTests: XCTestCase {
    private let montserrat: Set<Int> = [11, 12, 14, 16, 18]
    private let bricolage: Set<Int> = [12, 18, 20, 22, 24, 26, 32, 36, 40, 44]
    private let merriweather: Set<Int> = [24]

    func testEveryFontSizeIsOnTheFigmaScale() throws {
        let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FinancialNote")
        let files = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)!
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        let re = try NSRegularExpression(pattern: #"AppFont\.(main|heading|title)\((\d+)"#)
        var off: [String] = []
        for file in files where file.lastPathComponent != "Fonts.swift" {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (i, line) in lines.enumerated() {
                for m in re.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                    let fam = String(line[Range(m.range(at: 1), in: line)!])
                    let size = Int(line[Range(m.range(at: 2), in: line)!])!
                    let ok = fam == "main" ? montserrat.contains(size) : fam == "heading" ? bricolage.contains(size) : merriweather.contains(size)
                    if !ok { off.append("\(file.lastPathComponent):\(i + 1) \(fam) \(size)") }
                }
            }
        }
        XCTAssertTrue(off.isEmpty, "Off the type scale:\n" + off.joined(separator: "\n"))
    }
}
