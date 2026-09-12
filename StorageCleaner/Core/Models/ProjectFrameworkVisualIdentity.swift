import Foundation

/// Brand-inspired presentation metadata for a detected framework. Keeping it
/// beside the domain model gives every framework UI one shared identity.
struct ProjectFrameworkVisualIdentity: Equatable, Sendable {
    let mark: String
    let systemImage: String?
    let tintHex: String?
}

extension ProjectFramework {
    var visualIdentity: ProjectFrameworkVisualIdentity {
        switch self {
        case .react: .init(mark: "", systemImage: "atom", tintHex: "61DAFB")
        case .nextJS: .init(mark: "N", systemImage: nil, tintHex: nil)
        case .vue: .init(mark: "V", systemImage: nil, tintHex: "42B883")
        case .nuxt: .init(mark: "N", systemImage: nil, tintHex: "00DC82")
        case .quasar: .init(mark: "Q", systemImage: nil, tintHex: "1976D2")
        case .angular: .init(mark: "A", systemImage: nil, tintHex: "DD0031")
        case .svelte: .init(mark: "S", systemImage: nil, tintHex: "FF3E00")
        case .svelteKit: .init(mark: "SK", systemImage: nil, tintHex: "FF3E00")
        case .express: .init(mark: "Ex", systemImage: nil, tintHex: nil)
        case .nestJS: .init(mark: "N", systemImage: nil, tintHex: "E0234E")
        case .laravel: .init(mark: "L", systemImage: nil, tintHex: "FF2D20")
        case .symfony: .init(mark: "S", systemImage: nil, tintHex: nil)
        case .wordpress: .init(mark: "W", systemImage: nil, tintHex: "21759B")
        case .django: .init(mark: "Dj", systemImage: nil, tintHex: "0C9D74")
        case .flask: .init(mark: "F", systemImage: nil, tintHex: nil)
        case .fastAPI: .init(mark: "FA", systemImage: nil, tintHex: "009688")
        case .rubyOnRails: .init(mark: "R", systemImage: nil, tintHex: "D30001")
        case .sinatra: .init(mark: "Si", systemImage: nil, tintHex: "A67C52")
        case .springBoot: .init(mark: "", systemImage: "leaf.fill", tintHex: "6DB33F")
        case .ktor: .init(mark: "K", systemImage: nil, tintHex: "7F52FF")
        case .aspNetCore: .init(mark: ".NET", systemImage: nil, tintHex: "7B4FC9")
        case .blazor: .init(mark: "B", systemImage: nil, tintHex: "A855F7")
        case .vapor: .init(mark: "V", systemImage: nil, tintHex: "7B61FF")
        case .axum: .init(mark: "A", systemImage: nil, tintHex: "8B5CF6")
        case .actixWeb: .init(mark: "A", systemImage: nil, tintHex: nil)
        case .rocket: .init(mark: "", systemImage: "paperplane.fill", tintHex: "D33847")
        case .gin: .init(mark: "G", systemImage: nil, tintHex: "00ADD8")
        case .echo: .init(mark: "E", systemImage: nil, tintHex: "00B4AB")
        case .fiber: .init(mark: "F", systemImage: nil, tintHex: "00ACD7")
        }
    }
}
