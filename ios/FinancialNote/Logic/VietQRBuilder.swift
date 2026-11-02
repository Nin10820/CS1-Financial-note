import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Photos
import UIKit

/// Rebuilds a scanned VietQR with the amount (and note) the user typed: same account and bank,
/// tag 54 set, fresh CRC. Every Vietnamese bank app scans it from a photo with all of it filled in.
nonisolated extension VietQR {
    /// The same code with tag 01 = 12 (dynamic: has an amount), 54 = amount, 62 › 08 = note,
    /// and a fresh CRC (tag 63). Other fields stay as scanned, in their order.
    static func withAmount(_ payload: String, amount: Int, note: String) -> String? {
        let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("000201"), var f = ordered(text) else { return nil }
        f.removeAll { $0.id == "63" }
        set(&f, "01", "12")
        if amount > 0 {
            if let i = f.firstIndex(where: { $0.id == "54" }) {
                f[i].value = String(amount)
            } else {
                // 54 goes right after the currency (53), as in codes the banks make.
                let at = (f.firstIndex { $0.id == "53" }).map { $0 + 1 } ?? f.firstIndex { $0.id == "58" } ?? f.count
                f.insert(("54", String(amount)), at: at)
            }
        }
        let clean = ascii(note)
        if !clean.isEmpty {
            var extra = f.first { $0.id == "62" }.flatMap { ordered($0.value) } ?? []
            set(&extra, "08", clean)
            let value = join(extra)
            if let i = f.firstIndex(where: { $0.id == "62" }) { f[i].value = value } else {
                let at = f.firstIndex { $0.id == "63" } ?? f.count
                f.insert(("62", value), at: at)
            }
        }
        let body = join(f) + "6304"
        return body + crc16(body)
    }

    /// CRC-16/CCITT-FALSE (poly 0x1021, start 0xFFFF), four upper-case hex digits, as EMVCo asks.
    static func crc16(_ s: String) -> String {
        var crc: UInt16 = 0xFFFF
        for byte in s.utf8 {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = crc & 0x8000 != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return String(format: "%04X", crc)
    }

    /// True when the last four characters are the right CRC for the rest.
    static func crcIsValid(_ payload: String) -> Bool {
        guard payload.count > 8, payload.dropLast(4).hasSuffix("6304") else { return false }
        return crc16(String(payload.dropLast(4))) == String(payload.suffix(4))
    }

    /// Fields in their order ("IDLLvalue…"), or nil when it isn't TLV.
    static func ordered(_ s: String) -> [(id: String, value: String)]? {
        var out: [(id: String, value: String)] = []
        var i = s.startIndex
        while i < s.endIndex {
            guard s.distance(from: i, to: s.endIndex) >= 4 else { return nil }
            let idEnd = s.index(i, offsetBy: 2)
            let lenEnd = s.index(idEnd, offsetBy: 2)
            guard let len = Int(s[idEnd..<lenEnd]), s.distance(from: lenEnd, to: s.endIndex) >= len else { return nil }
            let valueEnd = s.index(lenEnd, offsetBy: len)
            out.append((String(s[i..<idEnd]), String(s[lenEnd..<valueEnd])))
            i = valueEnd
        }
        return out
    }

    private static func set(_ f: inout [(id: String, value: String)], _ id: String, _ value: String) {
        if let i = f.firstIndex(where: { $0.id == id }) { f[i].value = value } else { f.append((id, value)) }
    }

    private static func join(_ f: [(id: String, value: String)]) -> String {
        f.map { $0.id + String(format: "%02d", $0.value.count) + $0.value }.joined()
    }

    /// Bank notes take plain letters: "Bún bò Huế" → "Bun bo Hue", at most 25 characters.
    static func ascii(_ s: String) -> String {
        let folded = s.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
        let kept = folded.unicodeScalars.filter { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == " ") }
        return String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespaces).prefix(25).description
    }
}

/// The QR as a picture: the code on white with who it's for and the amount under it.
enum TransferQRImage {
    @MainActor
    static func make(payload: String, payee: String, detail: String, amount: Int) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let qrSide: CGFloat = 840
        let scaled = output.transformed(by: CGAffineTransform(scaleX: qrSide / output.extent.width, y: qrSide / output.extent.height))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        let size = CGSize(width: 1080, height: 1320)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.interpolationQuality = .none
            UIImage(cgImage: cg).draw(in: CGRect(x: 120, y: 100, width: qrSide, height: qrSide))
            let center = NSMutableParagraphStyle()
            center.alignment = .center
            func line(_ text: String, y: CGFloat, size: CGFloat, weight: UIFont.Weight, color: UIColor) {
                let font = UIFont.systemFont(ofSize: size, weight: weight)
                (text as NSString).draw(in: CGRect(x: 40, y: y, width: 1000, height: size * 1.4),
                                        withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: center])
            }
            line(payee, y: 990, size: 48, weight: .semibold, color: UIColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 1))
            line(detail, y: 1060, size: 36, weight: .regular, color: UIColor(red: 0.41, green: 0.46, blue: 0.53, alpha: 1))
            line("\(Money.format(amount)) đ", y: 1130, size: 60, weight: .bold, color: UIColor(red: 0.23, green: 0.41, blue: 0.13, alpha: 1))
        }
    }

    /// Adds the picture to Photos (asks once for "add only" access). False when not allowed.
    nonisolated static func save(_ image: UIImage) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            return false
        }
    }
}
