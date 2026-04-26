import Foundation

enum ModelFolderAccess {
    private static let bookmarkKey = "PokopiaModelFolderBookmark"

    static var selectedFolderDisplayName: String {
        guard let url = selectedFolderURL() else {
            return "No model folder selected"
        }
        return url.lastPathComponent
    }

    static func saveSelectedFolder(_ url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    static func selectedFolderURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                try saveSelectedFolder(url)
            }
            return url
        } catch {
            return nil
        }
    }
}
