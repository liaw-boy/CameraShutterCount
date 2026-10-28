import XCTest
@testable import CameraShutterCore

final class CanonPTPTests: XCTestCase {
    
    // Ground Truth captured from real EOS 5D Mark IV wire trace (firmware 1.2.1)
    // Recorded by mvisonneau/openshuttercounter in docs/PROTOCOL.md
    private let capturedMonOpenHex = "4d6f6e4f70656e0000000000000000000000000000000000000000000000000000000000"
    private let capturedMonCloseHex = "4d6f6e436c6f73650000000000000000000000000000000000000000000000000000000000"
    private let capturedMonRead100BHex = "4d6f6e52656164416e644765744461746100030000000200000002000000000000000000000000000000020000000b100000000000000000000000000000020000000a00000000000000000000000000000000000000"
    
    private func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 1. Wire Format Tests
    
    func testMonOpenPayloadMatchesGroundTruth() throws {
        let payload = try CanonFactoryPayload.buildCommand(name: "MonOpen")
        XCTAssertEqual(hexString(from: payload), capturedMonOpenHex, "MonOpen payload must match 5D Mark IV ground truth byte-for-byte")
        XCTAssertEqual(payload.count, 36, "MonOpen must be exactly 36 bytes (8 command + 4 argc + 24 trailer)")
    }
    
    func testMonClosePayloadMatchesGroundTruth() throws {
        let payload = try CanonFactoryPayload.buildCommand(name: "MonClose")
        XCTAssertEqual(hexString(from: payload), capturedMonCloseHex, "MonClose payload must match 5D Mark IV ground truth byte-for-byte")
        XCTAssertEqual(payload.count, 37, "MonClose must be exactly 37 bytes (9 command + 4 argc + 24 trailer)")
    }
    
    func testMonReadPayloadMatchesGroundTruth() throws {
        let payload = try CanonFactoryPayload.buildCommand(name: "MonReadAndGetData", args: [
            .init(tag: 2, value: 2),       // Constant mode tag = 2
            .init(tag: 2, value: 0x100B),   // Mirror address
            .init(tag: 2, value: 10)       // Length = 10 bytes
        ])
        XCTAssertEqual(hexString(from: payload), capturedMonRead100BHex, "MonReadAndGetData payload must match 5D Mark IV ground truth byte-for-byte")
        XCTAssertEqual(payload.count, 86, "MonReadAndGetData must be exactly 86 bytes (18 command + 4 argc + 60 args + 4 trailer)")
    }
    
    // MARK: - 2. Security & Hardware Protection Tests
    
    func testRefusesDangerousWriteCommands() {
        let forbidden = ["MonWrite", "FA_SetProperty", "FA_SetCalendar", "MonCall", "FA_FactoryReset"]
        for cmd in forbidden {
            XCTAssertThrowsError(try CanonFactoryPayload.buildCommand(name: cmd)) { error in
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, "CanonPTP")
                XCTAssertEqual(nsError.code, -100)
            }
        }
    }
    
    // MARK: - 3. Reply Decoding Tests
    
    func testDecodeCounterArithmeticAndCarry() {
        // Wire captures from real 5D Mark IV before & after taking exactly 20 frames
        let replyBefore: [UInt8] = [0x00, 0x66, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf2, 0x00]
        let replyAfter:  [UInt8] = [0x00, 0x67, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06]
        
        // (0x66 << 8) | 242 = 26,354
        let beforeCount = CanonFactoryPayload.decodeCounter(from: replyBefore)
        XCTAssertEqual(beforeCount, 26354)
        
        // (0x67 << 8) | 6 = 26,374 (exactly +20 after carry overflow)
        let afterCount = CanonFactoryPayload.decodeCounter(from: replyAfter)
        XCTAssertEqual(afterCount, 26374)
        
        XCTAssertEqual(afterCount! - beforeCount!, 20, "Counter must reflect exact 20 actuations")
    }
    
    // MARK: - 4. PTP Packet Framing Tests
    
    func testPTPCommandHeader() {
        let packet = PTPPacket.buildCommand(opCode: .getDevicePropValue, txId: 42, params: [0xD1AC])
        XCTAssertEqual(packet.count, 16, "Header 12 bytes + 1 parameter 4 bytes = 16 bytes")
        
        // Byte 0..3: Total Length = 16 (0x10, 0x00, 0x00, 0x00)
        XCTAssertEqual(packet[0], 0x10)
        XCTAssertEqual(packet[1], 0x00)
        
        // Byte 4..5: Container Type = 1 (Command)
        XCTAssertEqual(packet[4], 0x01)
        XCTAssertEqual(packet[5], 0x00)
        
        // Byte 6..7: Opcode = 0x1015 (GetDevicePropValue)
        XCTAssertEqual(packet[6], 0x15)
        XCTAssertEqual(packet[7], 0x10)
        
        // Byte 8..11: TxId = 42
        XCTAssertEqual(packet[8], 42)
        XCTAssertEqual(packet[9], 0x00)
        
        // Byte 12..15: Param = 0xD1AC
        XCTAssertEqual(packet[12], 0xAC)
        XCTAssertEqual(packet[13], 0xD1)
    }
}
