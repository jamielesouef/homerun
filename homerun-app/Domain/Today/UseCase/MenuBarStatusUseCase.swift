import Foundation

enum MenuBarStatusUseCase {
    static func status(for summary: TodaySummary) -> MenuBarStatus {
        let level: MenuBarStatus.Level

        switch (summary.syncProblems.isEmpty, summary.unfinishedWork.isEmpty) {
        case (false, _):
            level = .problems
        case (true, false):
            level = .localOnlyWork
        case (true, true):
            level = .allClear
        }

        return MenuBarStatus(
            level: level,
            localOnlyCount: summary.unfinishedWork.count,
            problemCount: summary.syncProblems.count,
            lastSuccessfulSync: summary.lastSuccessfulSync
        )
    }

    static func badgeText(for status: MenuBarStatus, showsCount: Bool) -> String? {
        guard showsCount, status.localOnlyCount > 0 else {
            return nil
        }

        return String(status.localOnlyCount)
    }
}
