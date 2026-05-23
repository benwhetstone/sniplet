import AppKit
import Foundation

@MainActor
final class AppUpdater {
    func installLatestAvailableBuild() {
        guard let currentURL = Bundle.main.bundleURL.standardizedFileURL as URL?,
              let candidateURL = newestCandidate(excluding: currentURL)
        else {
            showAlert(
                title: "No Update Found",
                message: "Sniplet could not find a newer local build. Put a newer Sniplet.app in Downloads, mount the installer DMG, or keep the project dist folder available."
            )
            return
        }

        let targetURL = URL(fileURLWithPath: "/Applications/Sniplet.app")
        let candidateDate = modificationDate(for: candidateURL) ?? .distantPast
        let currentDate = modificationDate(for: currentURL) ?? .distantPast

        guard candidateDate > currentDate || currentURL.path != targetURL.path else {
            showAlert(
                title: "Already Up To Date",
                message: "This installed copy is already as new as the local update source Sniplet found."
            )
            return
        }

        let script = """
        /bin/sleep 1
        /bin/rm -rf "\(targetURL.path)"
        /bin/cp -R "\(candidateURL.path)" "\(targetURL.path)"
        /usr/bin/open "\(targetURL.path)"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", script]

        do {
            try task.run()
            NSApplication.shared.terminate(nil)
        } catch {
            showAlert(
                title: "Update Failed",
                message: "Sniplet found an update but could not install it automatically."
            )
        }
    }

    private func newestCandidate(excluding currentURL: URL) -> URL? {
        candidateURLs()
            .map { $0.standardizedFileURL }
            .filter { $0 != currentURL }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .sorted { lhs, rhs in
                (modificationDate(for: lhs) ?? .distantPast) > (modificationDate(for: rhs) ?? .distantPast)
            }
            .first
    }

    private func candidateURLs() -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let downloads = home.appendingPathComponent("Downloads/Sniplet.app")
        let project = home.appendingPathComponent("Documents/Software Projects/Sniplet/dist/Sniplet.app")
        let mounted = URL(fileURLWithPath: "/Volumes/Sniplet/Sniplet.app")

        var urls = [downloads, project, mounted]

        if let volumes = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil
        ) {
            urls.append(contentsOf: volumes.map { $0.appendingPathComponent("Sniplet.app") })
        }

        return urls
    }

    private func modificationDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
