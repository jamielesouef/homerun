import Foundation

enum AppConstants {
    static let cloudKitContainerInfoKey = "HRCloudKitContainerIdentifier"
    static let localSettingsSuiteName = "mobi.jamie.homerun-app"

    static let toolSearchDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin"
    ]

    static let discoveryMaximumDepth = 6
    static let recentCommitLimit = 10
}
