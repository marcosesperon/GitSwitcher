import Foundation

/// Una versión publicada en GitHub Releases, con lo que la app necesita para
/// avisar y para actualizarse.
struct ReleaseInfo: Equatable, Sendable {
    struct Asset: Equatable, Sendable {
        let name: String
        let downloadURL: URL
        /// Huella SHA-256 que calcula GitHub para el fichero (en hexadecimal).
        let sha256: String?
        let size: Int
    }

    let version: AppVersion
    let notes: String
    let pageURL: URL
    /// El `.zip` de la app, si la release lo trae.
    let asset: Asset?
}

enum ReleaseFeedError: LocalizedError {
    case noReleases
    case rateLimited
    case http(Int)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .noReleases:
            return String(localized: "No versions have been published yet.")
        case .rateLimited:
            return String(localized: "GitHub is limiting requests right now. Try again in a while.")
        case .http(let code):
            return String(localized: "GitHub answered with an error (\(code)).")
        case .unexpectedResponse:
            return String(localized: "GitHub returned something GitSwitcher didn't understand.")
        }
    }
}

/// Pregunta a GitHub cuál es la última versión publicada.
///
/// Usa la API pública (sin token): no envía nada del usuario, solo pide un JSON
/// con la última release del repositorio.
enum ReleaseFeed {
    static let latestURL = URL(string: "https://api.github.com/repos/\(AppLinks.repositoryPath)/releases/latest")!

    static func fetchLatest(session: URLSession = .shared) async throws -> ReleaseInfo {
        var request = URLRequest(url: latestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GitSwitcher/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReleaseFeedError.unexpectedResponse }
        switch http.statusCode {
        case 200: return try parse(data)
        case 404: throw ReleaseFeedError.noReleases
        case 403, 429: throw ReleaseFeedError.rateLimited
        default: throw ReleaseFeedError.http(http.statusCode)
        }
    }

    // MARK: - Lectura del JSON (separado para poder probarlo)

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
            let digest: String?
            let size: Int
        }
        let tag_name: String
        let body: String?
        let html_url: URL
        let assets: [Asset]
    }

    static func parse(_ data: Data) throws -> ReleaseInfo {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let version = AppVersion(payload.tag_name) else {
            throw ReleaseFeedError.unexpectedResponse
        }
        // El zip se llama «GitSwitcher-X.Y.Z.zip» (lo genera release.sh). Si no
        // está con ese nombre, nos valemos del primer .zip que haya.
        let zips = payload.assets.filter { $0.name.hasSuffix(".zip") }
        let chosen = zips.first { $0.name == "GitSwitcher-\(version).zip" } ?? zips.first

        return ReleaseInfo(
            version: version,
            notes: (payload.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            pageURL: payload.html_url,
            asset: chosen.map { asset in
                ReleaseInfo.Asset(
                    name: asset.name,
                    downloadURL: asset.browser_download_url,
                    sha256: parseDigest(asset.digest),
                    size: asset.size
                )
            }
        )
    }

    /// GitHub da la huella como «sha256:abc…»; nos quedamos con la parte hex.
    static func parseDigest(_ digest: String?) -> String? {
        guard let digest, digest.lowercased().hasPrefix("sha256:") else { return nil }
        let hex = digest.dropFirst("sha256:".count).lowercased()
        return hex.count == 64 && hex.allSatisfy(\.isHexDigit) ? String(hex) : nil
    }
}
