import Foundation

enum AppVariant {
    #if POKOPIA_GITHUB
    static let isPersonalBuild = true
    static let displaySuffix = "GitHub"
    static let defaultModelFolder: URL? = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents", isDirectory: true)
        .appendingPathComponent("Pokopia Models", isDirectory: true)
    #else
    static let isPersonalBuild = false
    static let displaySuffix = ""
    static let defaultModelFolder: URL? = nil
    #endif
}
