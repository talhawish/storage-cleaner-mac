import Foundation

protocol BookmarkDataStoring: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ value: Data, forKey key: String)
    func removeObject(forKey key: String)
}

struct UserDefaultsBookmarkDataStore: BookmarkDataStoring, @unchecked Sendable {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func data(forKey key: String) -> Data? {
        userDefaults.data(forKey: key)
    }

    func set(_ value: Data, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}
