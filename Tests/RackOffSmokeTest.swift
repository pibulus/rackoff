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

        // Derive the expected month folder the same way the engine does, so this stays
        // correct regardless of the test machine's locale (month name is localized).
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let yearFolder = yearFormatter.string(from: fixtureDate())
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM-MMMM"
        let monthFolder = "\(yearFolder)/\(monthFormatter.string(from: fixtureDate()))"

        manager.organizationMode = .quickArchive
        let quickResult = await manager.vacuum()
        try expect(quickResult.errors.isEmpty, "Quick Archive returned errors: \(quickResult.errors)")
        try expect(quickResult.movedCount == 5, "Quick Archive moved \(quickResult.movedCount) files instead of 5")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("\(monthFolder)/Screenshot 2024-02-03 at 12.00.00 PM.png").path), "Quick Archive did not move screenshots into the monthly creation-date folder")
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("\(monthFolder)/report.pdf").path), "Quick Archive did not move documents into the monthly creation-date folder")
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
        try expect(fileManager.fileExists(atPath: archive.appendingPathComponent("2024/02-February/export.csv").path), "Smart Clean did not move archives into monthly folders")
        try expect(fileManager.fileExists(atPath: source.appendingPathComponent("holiday.png").path), "Smart Clean moved media even though Media was set to Skip")

        try await runDailyCatchUpChecks(in: root)
    }

    /// The daily schedule's promise ("clean every day at 9") only holds because of the
    /// catch-up check that runs on launch and on wake — a bare 24h Timer doesn't survive
    /// a laptop sleeping. These guard that catch-up fires exactly when it should and,
    /// just as importantly, never surprises the user when it shouldn't.
    @MainActor
    private static func runDailyCatchUpChecks(in root: URL) async throws {
        let fileManager = FileManager.default
        let calendar = Calendar.current
        let now = Date()
        let past = calendar.date(byAdding: .minute, value: -2, to: now)!
        let future = calendar.date(byAdding: .minute, value: 30, to: now)!
        let pastH = calendar.component(.hour, from: past)
        let pastM = calendar.component(.minute, from: past)
        let futH = calendar.component(.hour, from: future)
        let futM = calendar.component(.minute, from: future)

        func freshManager(_ label: String) throws -> (VacManager, URL) {
            let base = root.appendingPathComponent("sched-\(label)", isDirectory: true)
            let desk = base.appendingPathComponent("Desktop", isDirectory: true)
            let arch = base.appendingPathComponent("Stash", isDirectory: true)
            try fileManager.createDirectory(at: desk, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: arch, withIntermediateDirectories: true)
            let shot = desk.appendingPathComponent("Screenshot 2024-02-03 at 9.00.00 AM.png")
            try Data("rackoff\n".utf8).write(to: shot)
            let m = VacManager(loadStoredPreferences: false, sourceFolder: desk, destinationFolder: arch,
                               requestNotifications: false, sendNotifications: false,
                               ensureFolderAccess: false, setupSchedule: false, persistPreferences: false)
            m.fileTypes.indices.forEach { m.fileTypes[$0].isEnabled = true }
            m.organizationMode = .quickArchive
            return (m, desk)
        }

        func remaining(_ desk: URL) -> Int {
            ((try? fileManager.contentsOfDirectory(atPath: desk.path)) ?? []).filter { !$0.hasPrefix(".") }.count
        }

        func settle() async { try? await Task.sleep(nanoseconds: 1_200_000_000) }

        // Past-due and never ran → catch-up must clean (the woke-after-9am case).
        let (m1, desk1) = try freshManager("due")
        m1.schedule = .daily; m1.dailyCleaningHour = pastH; m1.dailyCleaningMinute = pastM
        m1.runDailyCatchUpIfNeeded()
        await settle()
        try expect(remaining(desk1) == 0, "Daily catch-up did not clean a past-due, never-run desktop")

        // Not yet due today → catch-up must NOT clean (forward timer's job).
        let (m2, desk2) = try freshManager("notyet")
        m2.schedule = .daily; m2.dailyCleaningHour = futH; m2.dailyCleaningMinute = futM
        m2.runDailyCatchUpIfNeeded()
        await settle()
        try expect(remaining(desk2) == 1, "Daily catch-up cleaned before the scheduled time")

        // Past-due but already cleaned today → must NOT double-clean.
        let (m3, desk3) = try freshManager("alreadyran")
        m3.schedule = .daily; m3.dailyCleaningHour = pastH; m3.dailyCleaningMinute = pastM; m3.lastRun = Date()
        m3.runDailyCatchUpIfNeeded()
        await settle()
        try expect(remaining(desk3) == 1, "Daily catch-up re-cleaned after already running today")

        // Manual mode → catch-up is inert even when a stale time looks past-due.
        let (m4, desk4) = try freshManager("manual")
        m4.schedule = .manual; m4.dailyCleaningHour = pastH; m4.dailyCleaningMinute = pastM
        m4.runDailyCatchUpIfNeeded()
        await settle()
        try expect(remaining(desk4) == 1, "Daily catch-up ran while in manual mode")
    }

    @MainActor
    private static func setDestination(_ destination: FileDestination, for name: String, in manager: VacManager) {
        guard let index = manager.fileTypes.firstIndex(where: { $0.name == name }) else { return }
        manager.fileTypes[index].destination = destination
    }

    /// The single creation date shared by every fixture. Used both to stamp the files
    /// and to compute the expected month folder, so the two can never drift apart.
    private static func fixtureDate() -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2024,
            month: 2,
            day: 3,
            hour: 12
        )) ?? Date()
    }

    private static func makeFixtures(in source: URL) throws {
        let date = fixtureDate()

        try writeFixture("Screenshot 2024-02-03 at 12.00.00 PM.png", in: source, date: date)
        try writeFixture("CleanShot 2024-02-03 at 12.01.00 PM.png", in: source, date: date)
        try writeFixture("report.pdf", in: source, date: date)
        try writeFixture("holiday.png", in: source, date: date)
        try writeFixture("export.csv", in: source, date: date)
        try writeFixture("random.tmp", in: source, date: date)
        try writeFixture(".hidden-screenshot.png", in: source, date: date)
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
