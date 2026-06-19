import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Shows a program's real macOS icon when one is available (cask `.app` bundles,
/// executables), falling back to the colored SF Symbol tile otherwise.
struct CLIProgramIconView: View {
    let program: CLIProgram
    var size: CGFloat = 38

    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.86, height: size * 0.86)
            } else {
                symbolTile
            }
        }
        .frame(width: size, height: size)
        .task(id: program.url) { await loadIcon() }
        .accessibilityHidden(true)
    }

    private var symbolTile: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(program.accent.opacity(0.14))
            .overlay {
                Image(systemName: program.symbolName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(program.accent)
                    .accessibilityHidden(true)
            }
    }

    private func loadIcon() async {
        let url = program.url
        // Resolve the icon source on a background thread (filesystem lookups);
        // NSWorkspace icon fetch itself stays on the main actor (AppKit, cached).
        let source = await Task.detached(priority: .utility) {
            CLIProgramIconLoader.iconSource(for: url)
        }.value

        guard let source else {
            icon = nil
            return
        }
        icon = CLIProgramIconLoader.distinctiveIcon(at: source)
    }
}

/// Decides whether a program has a meaningful real icon, and which file to read it
/// from. Plain directories (Homebrew kegs, node packages) have no useful icon and
/// return nil so the SF Symbol tile is used instead.
enum CLIProgramIconLoader {
    /// Returns the file's icon only when it's *distinctive* — i.e. not just the
    /// generic type icon (the default "Unix executable" page that opencode, node,
    /// etc. would otherwise show). Returns nil for generic icons so the caller can
    /// render the nicer colored SF Symbol tile instead.
    static func distinctiveIcon(at url: URL) -> NSImage? {
        let workspace = NSWorkspace.shared
        let icon = workspace.icon(forFile: url.path)

        guard let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType else {
            return icon
        }

        // Compare against the generic icon for this file's type; identical means the
        // file carries no custom icon of its own.
        let generic = workspace.icon(for: type)
        if let actual = icon.tiffRepresentation, let baseline = generic.tiffRepresentation, actual == baseline {
            return nil
        }
        return icon
    }

    static func iconSource(for url: URL) -> URL? {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }

        if url.pathExtension == "app" { return url }

        if isDirectory.boolValue {
            // Casks store the app a level or two down: <Caskroom>/<name>/<version>/<App>.app
            return nestedApp(in: url, fileManager: fileManager, depth: 2)
        }

        // A standalone executable carries its own Finder icon.
        if fileManager.isExecutableFile(atPath: url.path) { return url }
        return nil
    }

    private static func nestedApp(in directory: URL, fileManager: FileManager, depth: Int) -> URL? {
        guard depth > 0,
              let entries = try? fileManager.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: [.skipsHiddenFiles]
              )
        else {
            return nil
        }

        if let app = entries.first(where: { $0.pathExtension == "app" }) {
            return app
        }

        for entry in entries where (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            if let app = nestedApp(in: entry, fileManager: fileManager, depth: depth - 1) {
                return app
            }
        }
        return nil
    }
}
