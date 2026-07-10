import Foundation

/// `password` is intentionally excluded from `CodingKeys` — it's never written to
/// UserDefaults with the rest of the profile. TorrentStore reads/writes it via
/// KeychainHelper, keyed by `id`, and hydrates this field in memory after decoding.
struct ServerProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var port: String = "9091"
    var username: String = ""
    var password: String = ""

    enum CodingKeys: String, CodingKey { case id, name, host, port, username }
}
