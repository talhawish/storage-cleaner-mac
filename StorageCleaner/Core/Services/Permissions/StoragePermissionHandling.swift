protocol StoragePermissionHandling: Sendable {
    func currentStatuses() -> [StoragePermissionStatus]
    @MainActor
    func requestHomeFolderAccess() -> Bool
    func beginHomeFolderAccess() -> SecurityScopedResourceAccess?
}

extension StoragePermissionHandling {
    @MainActor
    func requestHomeFolderAccess() -> Bool {
        false
    }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        nil
    }
}

extension StoragePermissionHandling {
    /// Acquires the home folder security scope and invokes `body` with the
    /// scope active, releasing it on return. The access token passed to
    /// `body` is `nil` when the user hasn't granted home folder access; in
    /// that case `body` still runs (sandboxed directory enumerators will
    /// return nothing against protected paths). On an unsandboxed build —
    /// and in tests that inject a no-op handler — the token is `nil` and
    /// the work runs unchanged.
    ///
    /// Use this in every scan path that walks user files so the
    /// acquire/release lifecycle lives in one place and `beginHomeFolderAccess()`
    /// is only called once per scan. Callers that need to surface an
    /// "Access required" UX can check the token and bail out before
    /// running the body.
    func withHomeFolderAccess<T>(
        _ body: (SecurityScopedResourceAccess?) async -> T
    ) async -> T {
        let access = beginHomeFolderAccess()
        defer { access?.stop() }
        return await body(access)
    }
}
