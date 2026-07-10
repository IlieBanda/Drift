import Foundation
struct ServerProfile: Identifiable, Codable, Hashable { var id = UUID(); var name: String; var host: String; var port: String = "9091"; var username: String = ""; var password: String = "" }
