import XCTest
@testable import Swarm

final class TorrentFilterTests: XCTestCase {
    func testAllMatchesEveryStatus() {
        for status in Torrent.Status.allCases {
            XCTAssertTrue(TorrentFilter.all.matches(status))
        }
    }

    func testDownloadingMatchesOnlyDownloading() {
        XCTAssertTrue(TorrentFilter.downloading.matches(.downloading))
        XCTAssertFalse(TorrentFilter.downloading.matches(.seeding))
        XCTAssertFalse(TorrentFilter.downloading.matches(.paused))
    }

    func testSeedingMatchesOnlySeeding() {
        XCTAssertTrue(TorrentFilter.seeding.matches(.seeding))
        XCTAssertFalse(TorrentFilter.seeding.matches(.downloading))
        XCTAssertFalse(TorrentFilter.seeding.matches(.paused))
    }

    func testPausedMatchesOnlyPaused() {
        XCTAssertTrue(TorrentFilter.paused.matches(.paused))
        XCTAssertFalse(TorrentFilter.paused.matches(.downloading))
        XCTAssertFalse(TorrentFilter.paused.matches(.seeding))
    }
}
