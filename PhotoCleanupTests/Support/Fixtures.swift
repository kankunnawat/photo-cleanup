import Foundation
@testable import PhotoCleanup

enum Fixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    static func id(_ name: String) -> AssetID {
        AssetID(name)
    }

    static func photo(_ name: String, _ date: Date?, screenshot: Bool = false, favorite: Bool = false) -> AssetInfo {
        AssetInfo(id: id(name), isScreenshot: screenshot, creationDate: date, isFavorite: favorite)
    }

    static func video(_ name: String, _ date: Date?) -> AssetInfo {
        AssetInfo(id: id(name), kind: .video, creationDate: date, duration: 30)
    }
}
