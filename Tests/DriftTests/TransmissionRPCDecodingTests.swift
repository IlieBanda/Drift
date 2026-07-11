import XCTest
@testable import Drift

/// TransmissionClient's decoding is the most fragile seam in the app: different Transmission
/// daemon versions and configs can omit or reorder fields. These tests pin down decoding against
/// realistic RPC payloads so a daemon-version regression shows up here, not in a bug report.
final class TransmissionRPCDecodingTests: XCTestCase {
    func testDecodesTorrentGetResponseWithExactRequestedFields() throws {
        // Mirrors TransmissionClient.getTorrents()'s exact field list.
        let json = """
        {
          "arguments": {
            "torrents": [
              {
                "id": 1, "name": "Sintel", "status": 6, "percentDone": 1.0,
                "rateDownload": 0, "rateUpload": 1024, "totalSize": 129300000, "eta": -1,
                "uploadedEver": 0, "downloadedEver": 129300000, "uploadRatio": 0.0,
                "peersConnected": 3, "peersSendingToUs": 0, "peersGettingFromUs": 3
              }
            ]
          },
          "result": "success"
        }
        """
        let response = try JSONDecoder().decode(RPCResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.result, "success")
        let torrent = try XCTUnwrap(response.arguments?.torrents?.first)
        XCTAssertEqual(torrent.name, "Sintel")
        XCTAssertEqual(torrent.status, 6)
        XCTAssertEqual(torrent.peersConnected, 3)
    }

    func testDecodingFailsWhenARequestedFieldIsMissing() {
        // Documents the current strict-decoding behavior: if a daemon omits a field Drift asked
        // for, the whole torrent-get response fails to decode (surfaced to the user as a generic
        // connection error via TorrentStore.friendly(_:)) rather than partially degrading.
        let json = """
        {
          "arguments": {
            "torrents": [
              { "id": 1, "name": "Sintel", "status": 6, "percentDone": 1.0 }
            ]
          },
          "result": "success"
        }
        """
        XCTAssertThrowsError(try JSONDecoder().decode(RPCResponse.self, from: Data(json.utf8)))
    }

    func testDecodesTorrentDetailWithEmptyTrackersPeersAndFiles() throws {
        // A freshly-added torrent with no trackers/peers/files populated yet is a realistic
        // shape the daemon returns — must not crash the inspector.
        let json = """
        {
          "arguments": {
            "torrents": [
              {
                "id": 2, "name": "New Torrent", "hashString": "abc123", "comment": "",
                "isPrivate": false, "addedDate": 0, "doneDate": 0, "totalSize": 0,
                "sizeWhenDone": 0, "downloadedEver": 0, "uploadedEver": 0, "corruptEver": 0,
                "uploadRatio": 0.0, "errorString": "", "rateDownload": 0, "rateUpload": 0,
                "peersConnected": 0, "trackerStats": [], "peers": [], "files": [], "fileStats": []
              }
            ]
          },
          "result": "success"
        }
        """
        let response = try JSONDecoder().decode(TorrentDetailResponse.self, from: Data(json.utf8))
        let detail = try XCTUnwrap(response.arguments.torrents.first)
        XCTAssertEqual(detail.name, "New Torrent")
        XCTAssertTrue(detail.trackerStats.isEmpty)
        XCTAssertTrue(detail.peers.isEmpty)
        XCTAssertTrue(detail.files.isEmpty)
    }

    func testFreeSpaceResponseDecoding() throws {
        let json = """
        { "arguments": { "size-bytes": 52901234688 }, "result": "success" }
        """
        let response = try JSONDecoder().decode(FreeSpaceResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.arguments.sizeBytes, 52901234688)
    }
}
