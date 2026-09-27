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
        panel.message = "Choose \(defaultURL.path) to scan developer storage. "
            + "macOS may ask separately for protected folders during a full scan."
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

        return "Choose \(homePath). macOS may ask separately before protected folders are scanned."
    }
}

protocol ApplicationsFolderPicking: Sendable {
    @MainActor
    func pickApplicationsFolder(defaultURL: URL) -> URL?
}

struct NSOpenPanelApplicationsFolderPicker: ApplicationsFolderPicking {
    @MainActor
    func pickApplicationsFolder(defaultURL: URL) -> URL? {
        while true {
            let panel = NSOpenPanel()
            panel.title = "Choose Applications"
            panel.message = "Use \(defaultURL.path) so Storage Cleaner can inventory installed apps safely."
            panel.prompt = "Use Applications"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false
            panel.showsHiddenFiles = false
            panel.directoryURL = defaultURL

            guard panel.runModal() == .OK, let selectedURL = panel.url else { return nil }
            guard FileSystemPermissionService.isApplicationsFolder(selectedURL, expected: defaultURL) else {
                let alert = NSAlert()
                alert.messageText = "Choose the Applications folder"
                alert.informativeText = "Select \(defaultURL.path), not a folder inside it."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Choose Applications")
                alert.runModal()
                continue
            }
            return selectedURL.standardizedFileURL
        }
    }
}
