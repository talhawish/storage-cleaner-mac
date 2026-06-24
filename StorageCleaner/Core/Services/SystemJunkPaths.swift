import Foundation

/// System junk library locations and the static catalog of system/dev-tool bundle IDs that should
/// never be flagged as orphans. Kept in a dedicated file so `DependencyPaths` stays within the
/// 350-line type-body budget enforced by SwiftLint.
enum SystemJunkPaths {
    static let applicationSupport = SystemJunkPaths.home("Library/Application Support")
    static let caches = SystemJunkPaths.home("Library/Caches")
    static let containers = SystemJunkPaths.home("Library/Containers")
    static let groupContainers = SystemJunkPaths.home("Library/Group Containers")
    static let preferences = SystemJunkPaths.home("Library/Preferences")
    static let savedApplicationState = SystemJunkPaths.home("Library/Saved Application State")
    static let diagnosticReports = SystemJunkPaths.home("Library/Logs/DiagnosticReports")
    static let crashReporter = SystemJunkPaths.home("Library/Logs/CrashReporter")

    private static let home = UserHomeDirectory.url

    private static func home(_ path: String) -> URL {
        home.appendingPathComponent(path)
    }

    /// Apple system bundle IDs whose data is never orphaned because no `.app` for them is present
    /// in `/Applications`. They write to `~/Library/...` even though the app is hidden inside the
    /// macOS bundle. Keep this list curated and small — every entry is excluded from
    /// orphaned-data detection. `InstalledAppCatalog` adds the rest of the Apple `.app` bundle IDs
    /// discovered on disk.
    static let appleBundleIDs: Set<String> = [
        // Browsers (covered separately by BrowserCacheScanner, never orphaned)
        "com.apple.Safari",
        "com.apple.SafariServices",
        "com.apple.WebKit",
        "com.apple.WebKit.Networking",
        "com.apple.WebKit.WebContent",
        "com.apple.WebKit.GPU",
        "com.apple.WebKit.WebAuthnHelper",
        // First-party apps whose `.app` lives inside macOS and not in /Applications
        "com.apple.fileprovider.csstore",
        "com.apple.AppleFileConduit",
        "com.apple.AMPArtworkAgent",
        "com.apple.AMPDeviceDiscoveryAgent",
        "com.apple.AMPLibraryAgent",
        "com.apple.AMPSystemPolicyServer",
        "com.apple.CloudKit",
        "com.apple.CloudDocs",
        "com.apple.CoreAuth",
        "com.apple.CoreLocationAgent",
        "com.apple.Dictionary",
        "com.apple.FontBook",
        "com.apple.IconServices",
        "com.apple.InputMethodKit",
        "com.apple.iTunesCacheDelete",
        "com.apple.LaunchServices",
        "com.apple.LookupViewService",
        "com.apple.MailService",
        "com.apple.NetworkBrowser",
        "com.apple.ParentalControls",
        "com.apple.SpeechRecognitionCore",
        "com.apple.spotlight",
        "com.apple.SystemProfiler",
        "com.apple.TelephonyUtilities",
        "com.apple.TextInput",
        "com.apple.universalaccess",
        "com.apple.usbmuxd",
        "com.apple.Wallpaper",
        "com.apple.Xcode.DeveloperTools",
        "com.apple.XType",
        // Media & imaging daemons
        "com.apple.CoreMedia",
        "com.apple.coremedia.framework",
        "com.apple.CoreImage",
        "com.apple.CoreAnimation",
        "com.apple.imaging",
        "com.apple.ImageCapture",
        "com.apple.mobileslideshow",
        "com.apple.PhotoLibraryMigrationUtility"
    ]

    /// Apps that bundle storage in user Library but are very unlikely to be the only thing a user
    /// keeps "installed" — they're CLI tools, dev tools, or background services whose `.app` is
    /// inside an installer payload. Always considered "installed" so their Library entries are
    /// never orphaned even when no `.app` is on disk.
    static let alwaysInstalledBundleIDs: Set<String> = [
        "com.apple.dt.Xcode",
        "com.apple.dt.Instruments",
        "com.apple.dt.IBXcode",
        "com.apple.dt.IBAgent",
        "com.apple.iphonesimulator",
        "com.apple.CoreSimulator",
        "com.googlecode.iterm2",
        "com.github.atom",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.sublimetext.2",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.jetbrains.intellij",
        "com.jetbrains.intellij-ce",
        "com.jetbrains.toolbox",
        "com.docker.docker",
        "com.orbstack.OrbStack",
        "com.rancherdesktop.app",
        "com.lima-vm.lima"
    ]

    /// Bundles that look like app data but actually ship with macOS as a parallel install to the
    /// user's apps. Entries under these names in `~/Library/Application Support` are never flagged
    /// as orphans because they belong to a system framework the user did not install.
    static let reservedSupportDirectoryNames: Set<String> = [
        "Apple",
        "AppleConnect",
        "AppleScript",
        "Audio",
        "Automator",
        "BezelServices",
        "CloudDocs",
        "CoreSimulator",
        "CrashReporter",
        "DiskImages",
        "Dock",
        "FaceTime",
        "FontInstaller",
        "iconservices",
        "InputMethods",
        "Installer",
        "Keyboard",
        "LanguageModeling",
        "LaunchServices",
        "LocalStorage",
        "Login",
        "Mail",
        "MobileSync",
        "NotificationCenter",
        "ParentalControls",
        "passes",
        "Preferences",
        "PrinterProxy",
        "Quick Look",
        "QuickLook",
        "Screen Sharing",
        "Script Editor",
        "ScreenSaver",
        "Spelling",
        "Spotlight",
        "Stickers",
        "SyncServices",
        "SystemConfiguration",
        "TextInput",
        "VoiceTrigger",
        "Wallpaper",
        "WebEx",
        "Xcode",
        "Xcode3",
        "XcodeKit",
        "com.apple.inputmethod.emoji"
    ]
}
