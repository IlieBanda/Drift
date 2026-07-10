import Foundation

struct SessionSettings: Decodable {
    var speedLimitDownEnabled: Bool
    var speedLimitDown: Int
    var speedLimitUpEnabled: Bool
    var speedLimitUp: Int
    var altSpeedEnabled: Bool
    var altSpeedDown: Int
    var altSpeedUp: Int
    var downloadDir: String

    enum CodingKeys: String, CodingKey {
        case speedLimitDownEnabled = "speed-limit-down-enabled"
        case speedLimitDown = "speed-limit-down"
        case speedLimitUpEnabled = "speed-limit-up-enabled"
        case speedLimitUp = "speed-limit-up"
        case altSpeedEnabled = "alt-speed-enabled"
        case altSpeedDown = "alt-speed-down"
        case altSpeedUp = "alt-speed-up"
        case downloadDir = "download-dir"
    }
}
