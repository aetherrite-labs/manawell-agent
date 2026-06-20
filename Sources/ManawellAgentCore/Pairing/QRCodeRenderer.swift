//
//  QRCodeRenderer.swift
//  ManawellAgentCore
//

import Foundation
import QRCodeGenerator

/// Renders a QR code for a string. The terminal form packs two QR rows into each text
/// line with Unicode half-blocks and forces black-on-white via ANSI, so a phone camera
/// can scan it straight out of a dark terminal. The menu-bar app will reuse the same
/// `QRCode` module matrix to draw an on-screen image.
public enum QRCodeRenderer {
    public static func terminalString(for text: String, quietZone: Int = 4) throws -> String {
        let qr = try QRCode.encode(text: text, ecl: .medium)
        let size = qr.size

        // Dark module lookup with an implicit light "quiet zone" border.
        func isDark(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, y >= 0, x < size, y < size else { return false }
            return qr.getModule(x: x, y: y)
        }

        let blackOnWhite = "\u{1b}[30;107m" // black fg, bright-white bg
        let reset = "\u{1b}[0m"
        let lo = -quietZone
        let hi = size + quietZone - 1

        var lines: [String] = []
        var y = lo
        while y <= hi {
            var line = blackOnWhite
            for x in lo...hi {
                switch (isDark(x, y), isDark(x, y + 1)) {
                case (true, true): line += "\u{2588}"   // █
                case (true, false): line += "\u{2580}"  // ▀
                case (false, true): line += "\u{2584}"  // ▄
                case (false, false): line += " "
                }
            }
            line += reset
            lines.append(line)
            y += 2
        }
        return lines.joined(separator: "\n")
    }
}
