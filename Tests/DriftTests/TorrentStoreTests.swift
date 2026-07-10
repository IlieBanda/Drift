import XCTest
@testable import Drift

@MainActor
final class TorrentStoreTests: XCTestCase {
    private func torrent(id: Int, status: Torrent.Status) -> Torrent {
        Torrent(id: id, name: "T\(id)", status: status, progress: 0.5, speed: "—", size: "1 MB", eta: "—")
    }

    func testSelectedTorrentsFiltersBySelectedIDs() {
        let store = TorrentStore(torrents: [torrent(id: 1, status: .downloading), torrent(id: 2, status: .paused), torrent(id: 3, status: .seeding)])
        store.selectedIDs = [1, 3]
        XCTAssertEqual(Set(store.selectedTorrents.map(\.id)), [1, 3])
    }

    func testCountForFilter() {
        let store = TorrentStore(torrents: [torrent(id: 1, status: .downloading), torrent(id: 2, status: .paused), torrent(id: 3, status: .paused)])
        XCTAssertEqual(store.count(for: .all), 3)
        XCTAssertEqual(store.count(for: .downloading), 1)
        XCTAssertEqual(store.count(for: .paused), 2)
        XCTAssertEqual(store.count(for: .seeding), 0)
    }

    func testSelectionIsPausedRequiresAllSelectedPaused() {
        let store = TorrentStore(torrents: [torrent(id: 1, status: .paused), torrent(id: 2, status: .paused), torrent(id: 3, status: .downloading)])
        store.selectedIDs = [1, 2]
        XCTAssertTrue(store.selectionIsPaused)
        store.selectedIDs = [1, 3]
        XCTAssertFalse(store.selectionIsPaused)
        store.selectedIDs = []
        XCTAssertFalse(store.selectionIsPaused)
    }

    func testFriendlyErrorMessagesForKnownURLErrorCodes() {
        let store = TorrentStore()
        XCTAssertTrue(store.friendly(URLError(.timedOut)).contains("did not respond"))
        XCTAssertTrue(store.friendly(URLError(.cannotConnectToHost)).contains("unavailable"))
        XCTAssertTrue(store.friendly(URLError(.appTransportSecurityRequiresSecureConnection)).contains("HTTPS"))
    }

    func testFriendlyErrorMessageForNonURLErrorDoesNotLeakRawDomainCode() {
        let store = TorrentStore()
        struct SomeOtherError: Error {}
        let message = store.friendly(SomeOtherError())
        XCTAssertFalse(message.contains("NSError"))
        XCTAssertFalse(message.contains("Domain"))
    }
}
