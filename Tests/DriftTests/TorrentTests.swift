import XCTest
@testable import Drift

final class TorrentTests: XCTestCase {
    func testPercentTextRounds() {
        XCTAssertEqual(Torrent.percentText(0), "0%")
        XCTAssertEqual(Torrent.percentText(0.5), "50%")
        XCTAssertEqual(Torrent.percentText(0.999), "100%")
        XCTAssertEqual(Torrent.percentText(1), "100%")
    }

    func testFormattedETAUnknownWhenNegative() {
        XCTAssertEqual(Torrent.formattedETA(-1), "—")
        XCTAssertEqual(Torrent.formattedETA(0), "—")
    }

    func testFormattedETAProducesNonEmptyStringForPositiveValues() {
        XCTAssertNotEqual(Torrent.formattedETA(30), "—")
        XCTAssertNotEqual(Torrent.formattedETA(3600), "—")
        XCTAssertNotEqual(Torrent.formattedETA(90000), "—")
    }

    private func remote(status: Int, ratio: Double = 0) -> RemoteTorrent {
        RemoteTorrent(id: 1, name: "Test", status: status, percentDone: 0.5, rateDownload: 0, rateUpload: 0, totalSize: 1000, eta: -1, uploadedEver: 0, downloadedEver: 500, uploadRatio: ratio, peersConnected: 0, peersSendingToUs: 0, peersGettingFromUs: 0)
    }

    func testStatusMappingFromRPCStatusCodes() {
        XCTAssertEqual(Torrent(remote: remote(status: 0)).status, .paused)
        XCTAssertEqual(Torrent(remote: remote(status: 1)).status, .paused)
        XCTAssertEqual(Torrent(remote: remote(status: 2)).status, .paused)
        XCTAssertEqual(Torrent(remote: remote(status: 4)).status, .downloading)
        XCTAssertEqual(Torrent(remote: remote(status: 5)).status, .seeding)
        XCTAssertEqual(Torrent(remote: remote(status: 6)).status, .seeding)
    }

    func testRatioTextHandlesTransmissionSentinels() {
        XCTAssertEqual(Torrent(remote: remote(status: 6, ratio: -1)).ratioText, "—")
        XCTAssertEqual(Torrent(remote: remote(status: 6, ratio: -2)).ratioText, "—")
        XCTAssertEqual(Torrent(remote: remote(status: 6, ratio: 1.5)).ratioText, 1.5.formatted(.number.precision(.fractionLength(2))))
    }
}
