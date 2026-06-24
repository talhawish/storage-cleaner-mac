import AppKit
import Foundation

protocol HomeFolderPicking: Sendable {
    @MainActor
    func pickHomeFolder(defaultURL: URL) -> URL?
}

struct NSOpenPanelHomeFolderPicker: HomeFolderPicking {
    @MainActor
    func pickHomeFolder(defaultURL: URL) -> URL? {
        while true {
            let panel = makePanel(defaultURL: defaultURL)

            guard panel.runModal() == .OK else { return nil }
            guard let selectedURL = panel.url else { return nil }
            guard FileSystemPermissionService.isHomeFolder(selectedURL, homeDirectory: defaultURL) else {
                showInvalidSelectionAlert(selectedURL: selectedURL, homeURL: defaultURL)
                continue
            }
            return selectedURL
        }
    }

    @MainActor
    private func makePanel(defaultURL: URL) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = "Choose \(defaultURL.lastPathComponent)"
        panel.message = "Use \(defaultURL.path) so StorageCleaner can build one complete cleanup report."
        panel.prompt = "Use Home Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = false
        panel.directoryURL = defaultURL
        return panel
    }

    @MainActor
    private func showInvalidSelectionAlert(selectedURL: URL, homeURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Choose your Home folder"
        alert.informativeText = invalidSelectionMessage(selectedURL: selectedURL, homeURL: homeURL)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Choose Home Folder")
        alert.runModal()
    }

    private func invalidSelectionMessage(selectedURL: URL, homeURL: URL) -> String {
        let selectedPath = selectedURL.standardizedFileURL.path
        let homePath = homeURL.standardizedFileURL.path
        let usersPath = homeURL.deletingLastPathComponent().standardizedFileURL.path

        if selectedPath == usersPath {
            return """
            StorageCleaner only needs your account's Home folder, not the shared Users folder. \
            Choose \(homeURL.lastPathComponent) at \(homePath).
            """
        }

        return "Choose \(homePath) so Desktop, Documents, Downloads, Pictures, and Movies can be scanned together."
    }
}
