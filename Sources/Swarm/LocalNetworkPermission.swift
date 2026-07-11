import Network
enum LocalNetworkPermission { private static var browser: NWBrowser?; static func request() { guard browser == nil else { return }; let item = NWBrowser(for: .bonjour(type: "_transmission._tcp", domain: nil), using: .tcp); browser = item; item.start(queue: .main) } }
