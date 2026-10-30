import SwiftUI
import UIKit
import VisionKit

/// Turns what the camera read into note lines: trimmed, single-spaced, empty ones dropped.
nonisolated enum ScanText {
    static func lines(from texts: [String]) -> [String] {
        texts.flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
    }
}

/// The live camera from VisionKit (DataScannerViewController). SwiftUI has no camera view of
/// its own, so this is the one UIKit piece. Everything is read on the phone; no photo is kept.
struct CameraScanner: UIViewControllerRepresentable {
    enum Mode { case qr, text }

    var mode: Mode
    /// QR: called once with the first code read.
    var onCode: (String) -> Void
    /// Text: the lines on screen right now, top to bottom (refreshed as the camera moves).
    var onText: ([String]) -> Void

    static var isSupported: Bool { DataScannerViewController.isSupported }
    static var isAvailable: Bool { DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let types: Set<DataScannerViewController.RecognizedDataType> = mode == .qr
            ? [.barcode(symbologies: [.qr])]
            : [.text(languages: ["vi", "en"])]
        let vc = DataScannerViewController(
            recognizedDataTypes: types,
            qualityLevel: mode == .qr ? .fast : .accurate,
            recognizesMultipleItems: mode == .text,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) {
        vc.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: CameraScanner
        private var sentCode = false

        init(parent: CameraScanner) { self.parent = parent }

        func dataScanner(_ scanner: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(allItems)
        }

        func dataScanner(_ scanner: DataScannerViewController, didUpdate updated: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(allItems)
        }

        func dataScanner(_ scanner: DataScannerViewController, didRemove removed: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(allItems)
        }

        private func handle(_ items: [RecognizedItem]) {
            switch parent.mode {
            case .qr:
                guard !sentCode else { return }
                for case .barcode(let code) in items {
                    if let payload = code.payloadStringValue {
                        sentCode = true
                        parent.onCode(payload)
                        return
                    }
                }
            case .text:
                // Read top to bottom, then left to right, like a receipt.
                let texts = items.compactMap { item -> (CGPoint, String)? in
                    guard case .text(let t) = item else { return nil }
                    return (t.bounds.topLeft, t.transcript)
                }
                .sorted { abs($0.0.y - $1.0.y) < 12 ? $0.0.x < $1.0.x : $0.0.y < $1.0.y }
                .map(\.1)
                parent.onText(ScanText.lines(from: texts))
            }
        }
    }
}
