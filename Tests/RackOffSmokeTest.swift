import Foundation

enum SmokeTestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

@main
struct RackOffSmokeTest {
    static func main() async {
        do {
            try await run()
            print("RackOff smoke test passed")
        } catch {
            fputs("RackOff smoke test failed: \(error)\n", stderr)
            exit(1)
        }
    }

    @MainActor
    private static func run() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("RackOffSmokeTest-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("Desktop", isDirectory: true)
        let archive = root.appendingPathComponent("Archive", isDirectory: true)

        try fileManager.createDirectory(at: source, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: archive, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let manager = VacManager(
            loadStoredPreferences: false,
            sourceFolder: source,
            destinationFolder: archive,
            requestNotifications: false,
            sendNotifications: false,
            ensureFolderAccess: false,
            setupSchedule: false,
            persistPreferences: false
        )

        try makeFixtures(in: source)
        manager.fileTypes.indices.forEach { manager.fileTypes[$0].isEnabled = true }

        manager.organizationMode = .quickArchive
        let quickResult = await manager.vacuum()
        try expect(quickResult.errors.isEmpty, "Quick Archive returned errors: \(quickResult.errors)")
        try expect(quickResult.movedCount == 5, "Quick Archive moved \(quickResult.movedCount) files instead of 5")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("2024-02/Screenshot 2024-02-03 at 12.00.00 PM.png").path), "Quick Archive did not move screenshots into the monthly creation-date folder")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("2024-02/report.pdf").path), "Quick Archive did not move documents into the monthly creation-date folder")
        try expect(fileManager.fileExists(atPath: source.appendingPathComponent("random.tmp").path), "Quick Archive moved an unmatched file")
        try expect(fileManager.fileExists(atPath: source.appendingPathComponent(".hidden-screenshot.png").path), "Quick Archive moved a hidden file")

        let quickUndo = await manager.undoLastClean()
        try expect(quickUndo.errors.isEmpty, "Quick Archive undo returned errors: \(quickUndo.errors)")
        try expect(quickUndo.restoredCount == 5, "Quick Archive undo restored \(quickUndo.restoredCount) files instead of 5")
        try resetArchive(at: archive)

        manager.organizationMode = .sortByType
        let sortResult = await manager.vacuum()
        try expect(sortResult.errors.isEmpty, "Sort by Type returned errors: \(sortResult.errors)")
        try expect(sortResult.movedCount == 5, "Sort by Type moved \(sortResult.movedCount) files instead of 5")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("Screenshots/CleanShot 2024-02-03 at 12.01.00 PM.png").path), "Sort by Type did not move CleanShot files into Screenshots")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("Documents/report.pdf").path), "Sort by Type did not move documents into Documents")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("Media/holiday.png").path), "Sort by Type did not move non-screenshot images into Media")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("Archives/export.csv").path), "Sort by Type did not move CSV files into Archives")

        let sortUndo = await manager.undoLastClean()
        try expect(sortUndo.errors.isEmpty, "Sort by Type undo returned errors: \(sortUndo.errors)")
        try expect(sortUndo.restoredCount == 5, "Sort by Type undo restored \(sortUndo.restoredCount) files instead of 5")
        try resetArchive(at: archive)

        manager.organizationMode = .smartClean
        setDestination(.daily, for: "Screenshots", in: manager)
        setDestination(.typeFolder, for: "Documents", in: manager)
        setDestination(.skip, for: "Media", in: manager)
        setDestination(.monthly, for: "Archives", in: manager)

        let smartResult = await manager.vacuum()
        try expect(smartResult.errors.isEmpty, "Smart Clean returned errors: \(smartResult.errors)")
        try expect(smartResult.movedCount == 4, "Smart Clean moved \(smartResult.movedCount) files instead of 4")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("2024-02-03/Screenshot 2024-02-03 at 12.00.00 PM.png").path), "Smart Clean did not move screenshots into daily folders")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("Documents/report.pdf").path), "Smart Clean did not move documents into Documents")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("2024-02/export.csv").path), "Smart Clean did not move archives into monthly folders")
        try expect(fileManager.fileExists(atPath: source.appendingPathComponent("holiday.png").path), "Smart Clean moved media even though Media was set to Skip")
    }

    @MainActor
    private static func setDestination(_ destination: FileDestination, for name: String, in manager: VacManager) {
        guard let index = manager.fileTypes.firstIndex(where: { $0.name == name }) else { return }
        manager.fileTypes[index].destination = destination
    }

    private static func makeFixtures(in source: URL) throws {
        let fixtureDate = Calendar(identifier: .gregorian).date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2024,
            month: 2,
            day: 3,
            hour: 12
        )) ?? Date()

        try writeFixture("Screenshot 2024-02-03 at 12.00.00 PM.png", in: source, date: fixtureDate)
        try writeFixture("CleanShot 2024-02-03 at 12.01.00 PM.png", in: source, date: fixtureDate)
        try writeFixture("report.pdf", in: source, date: fixtureDate)
        try writeFixture("holiday.png", in: source, date: fixtureDate)
        try writeFixture("export.csv", in: source, date: fixtureDate)
        try writeFixture("random.tmp", in: source, date: fixtureDate)
        try writeFixture(".hidden-screenshot.png", in: source, date: fixtureDate)
        try FileManager.default.createDirectory(at: source.appendingPathComponent("Screenshot folder", isDirectory: true), withIntermediateDirectories: true)
    }

    private static func writeFixture(_ name: String, in source: URL, date: Date) throws {
        let url = source.appendingPathComponent(name)
        try Data("rackoff smoke test\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.creationDate: date, .modificationDate: date], ofItemAtPath: url.path)
    }

    private static func resetArchive(at archive: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: archive.path) {
            try fileManager.removeItem(at: archive)
        }
        try fileManager.createDirectory(at: archive, withIntermediateDirectories: true)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw SmokeTestFailure.failed(message)
        }
    }
}
