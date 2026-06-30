//
//  Extension.swift
//  AudioPlayerUI
//
//  Created by William.Weng on 2026/6/26.
//

import Foundation
import SwiftUI

// MARK: - JSONSerialization (subscript function)
extension Collection {
    
    /// 集合安全取值
    /// - Returns: Element?
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - TimeInterval (function)
extension TimeInterval {
 
    /// [秒 => 時間 (210.2799sec => 3 minutes, 30 seconds)](https://stackoverflow.com/questions/26794703/swift-integer-conversion-to-hours-minutes-seconds)
    /// - Parameter unitsStyle: 輸出的方式 => .full
    /// - Parameter allowedUnits: 想要看的單位 => [.hour, .minute, .second]
    /// - Parameter behavior: 處理0的顯示問題
    /// - Parameter localeIdentifier: 語言代號 => en-US
    /// - Returns: String?
    func time(unitsStyle: DateComponentsFormatter.UnitsStyle = .full, allowedUnits: NSCalendar.Unit = [.hour, .minute, .second], behavior: DateComponentsFormatter.ZeroFormattingBehavior = .default, localeIdentifier: String = "en-US") -> String? {
        
        let calendar = Calendar.build(localeIdentifier: localeIdentifier)
        let formatter = DateComponentsFormatter()
        
        formatter.calendar = calendar
        formatter.allowedUnits = allowedUnits
        formatter.unitsStyle = unitsStyle
        formatter.zeroFormattingBehavior = behavior
        
        return formatter.string(from: self)
    }
}

// MARK: - Color
extension Color {
    
    /// 16進制顏色轉換
    ///   - colorSpace: 色彩空間
    ///   - hex: 16進制顏色色碼 (#0d1117)
    init(colorSpace: Color.RGBColorSpace = .sRGB, hex: String) {
        
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        let opacity = Double(1.0)
        
        self.init(colorSpace, red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - URL
extension URL {
    
    /// 搜尋目錄下所有符合副檔名條件的音訊檔
    /// - Parameter audioExtensions: 允許搜尋的音訊副檔名字集合，預設包含 mp3、m4a、aac、wav、flac
    /// - Returns: 符合條件的音訊檔 URL 清單
    func searchAudios(extensions audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "flac"]) -> [URL] {
        
        let keys: [URLResourceKey] = [.isRegularFileKey]
        
        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsHiddenFiles,
            .skipsPackageDescendants
        ]
        
        guard let enumerator = FileManager.default.enumerator(at: self, includingPropertiesForKeys: keys, options: options) else { return [] }
        
        var results: [URL] = []
        results.reserveCapacity(64)
        
        for case let url as URL in enumerator {
            
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true
            else {
                continue
            }
            
            guard audioExtensions.contains(url.pathExtension.lowercased()) else {
                continue
            }
            
            results.append(url)
        }
        
        return results
    }
}

// MARK: - Calendar (static function)
private extension Calendar {
    
    /// 產生本地端的日曆
    /// - Parameter localeIdentifier: [語言代號 (zh-Hant-TW)](http://www.iana.org/assignments/language-subtag-registry/language-subtag-registry)
    /// - Returns: Calendar
    static func build(localeIdentifier: String = "en-US") -> Self {
        
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: localeIdentifier)

        return calendar
    }
}
