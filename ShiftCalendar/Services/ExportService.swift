import Foundation
import SwiftUI
import UIKit

enum ExportService {
    static func temporaryURL(name: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftExport", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    // MARK: - Календарь (.ics)

    static func makeICS(data: ScheduleData, month: Date) -> URL? {
        let start = Cal.startOfMonth(month)
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//ShiftCalendar//Shift Calendar//RU",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:Смены",
            "X-WR-TIMEZONE:UTC"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"

        let stamp = formatter.string(from: Date())

        for date in data.days(in: start) {
            guard let type = data.shiftType(for: date), type.isWorking else { continue }

            let dayStart = Cal.calendar.date(
                bySettingHour: type.startMinutes / 60,
                minute: type.startMinutes % 60,
                second: 0,
                of: date
            ) ?? date

            let hours = data.hours(for: date)
            let end = dayStart.addingTimeInterval(max(hours, 0.5) * 3600)

            var description = "\(type.name), \(Fmt.hours(hours))"
            let note = data.note(for: date)
            if !note.isEmpty {
                description += ". " + note
            }

            lines.append("BEGIN:VEVENT")
            lines.append("UID:\(Cal.dayKey(date))-\(type.id.uuidString)@shifty")
            lines.append("DTSTAMP:\(stamp)")
            lines.append("DTSTART:\(formatter.string(from: dayStart))")
            lines.append("DTEND:\(formatter.string(from: end))")
            lines.append("SUMMARY:\(escape("Смена " + type.name))")
            lines.append("DESCRIPTION:\(escape(description))")
            lines.append("END:VEVENT")
        }

        lines.append("END:VCALENDAR")

        let text = lines.joined(separator: "\r\n") + "\r\n"
        let url = temporaryURL(name: "Смены-\(monthFilePart(month)).ics")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - PDF

    @MainActor
    static func makePDF(data: ScheduleData, month: Date) -> URL? {
        let size = CGSize(width: 595, height: 842)
        let content = MonthPDFView(data: data, month: month)
            .frame(width: size.width, height: size.height)
            .background(Color.white)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        let url = temporaryURL(name: "Смены-\(monthFilePart(month)).pdf")
        var mediaBox = CGRect(origin: .zero, size: size)

        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return nil }

        renderer.render { renderedSize, draw in
            var box = CGRect(origin: .zero, size: renderedSize)
            context.beginPage(mediaBox: &box)
            draw(context)
            context.endPage()
        }
        context.closePDF()

        return url
    }

    private static func monthFilePart(_ month: Date) -> String {
        String(format: "%04d-%02d", Cal.year(month), Cal.monthNumber(month))
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

/// Системный шит «Поделиться».
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
