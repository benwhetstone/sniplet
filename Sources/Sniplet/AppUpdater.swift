import AppKit
import Foundation

@MainActor
final class AppUpdater {
    private let owner = "benwhetstone"
    private let repository = "sniplet"
    private let preferredAssetName = "Sniplet-Installer.dmg"

    func installLatestAvailableBuild() {
        Task { @MainActor in
            do {
                let release = try await fetchLatestRelease()
                let currentVersion = currentAppVersion()
                let latestVersion = releaseVersion(from: release.tagName)

                guard isNewerRelease(latestVersion, than: currentVersion) else {
                    showAlert(
                        title: "Already Up To Date",
                        message: "This copy of Sniplet already matches the latest GitHub release."
                    )
                    return
                }

                let targetURL = releaseDownloadURL(from: release) ?? release.htmlURL
                NSWorkspace.shared.open(targetURL)

                showAlert(
                    title: "Update Ready",
                    message: "Sniplet opened the latest GitHub download. After the disk image opens, open 1 - Start Here.html and run the one-line Terminal install command. macOS will ask for your password once to install and approve the update on this Mac."
                )
            } catch {
                showAlert(
                    title: "Update Failed",
                    message: "Sniplet could not check GitHub Releases right now."
                )
            }
        }
    }

    func releaseVersion(from tagName: String) -> String {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v"), trimmed.count > 1 {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    func isNewerRelease(_ latestVersion: String, than currentVersion: String) -> Bool {
        latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending
    }

    func releaseDownloadURL(from release: GitHubRelease) -> URL? {
        release.assets.first(where: { $0.name == preferredAssetName })?.browserDownloadURL
            ?? release.assets.first(where: { $0.name.hasSuffix(".dmg") })?.browserDownloadURL
    }

    private func currentAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let endpoint = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Sniplet-Updater", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw UpdaterError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]
}

struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL
}

private enum UpdaterError: Error {
    case invalidResponse
}
