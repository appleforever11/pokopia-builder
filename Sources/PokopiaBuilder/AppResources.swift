import Foundation

enum AppResources {
    static var bundle: Bundle {
        resourceBundle ?? Bundle.main
    }

    private static let resourceBundle: Bundle? = {
        let bundleName = "PokopiaBuilder_PokopiaBuilder.bundle"
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(bundleName, isDirectory: true))
        }

        candidates.append(Bundle.main.bundleURL.appendingPathComponent(bundleName, isDirectory: true))
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(bundleName)", isDirectory: true))

        if let executableURL = Bundle.main.executableURL {
            candidates.append(executableURL.deletingLastPathComponent().appendingPathComponent(bundleName, isDirectory: true))
        }

        return candidates.lazy.compactMap { url in
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return Bundle(url: url)
        }.first
    }()
}
