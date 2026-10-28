import Foundation
import ImageCaptureCore

public protocol CameraDriver: Sendable {
    var brand: CameraBrand { get }
    func canHandle(deviceName: String, manufacturer: String?) -> Bool
    func readShutter(camera: ICCameraDevice, nextTxId: @escaping @Sendable () -> UInt32, logger: @escaping @Sendable (String) -> Void) async throws -> ShutterReport
}

public final class CameraDriverRegistry: @unchecked Sendable {
    public static let shared = CameraDriverRegistry()
    
    private var drivers: [CameraDriver] = []
    
    public init() {
        // Register supported brand drivers
        register(driver: CanonDriver())
        register(driver: NikonDriver())
        register(driver: SonyDriver())
    }
    
    public func register(driver: CameraDriver) {
        drivers.append(driver)
    }
    
    public func findDriver(deviceName: String, manufacturer: String?) -> CameraDriver? {
        for driver in drivers {
            if driver.canHandle(deviceName: deviceName, manufacturer: manufacturer) {
                return driver
            }
        }
        return nil
    }
}

// MARK: - 1. Canon Driver
public struct CanonDriver: CameraDriver {
    public let brand: CameraBrand = .canon
    
    public init() {}
    
    public func canHandle(deviceName: String, manufacturer: String?) -> Bool {
        CameraBrand.detect(from: deviceName, manufacturer: manufacturer) == .canon
    }
    
    public func readShutter(
        camera: ICCameraDevice,
        nextTxId: @escaping @Sendable () -> UInt32,
        logger: @escaping @Sendable (String) -> Void
    ) async throws -> ShutterReport {
        // Step 1: Try Legacy PTP 0xD1AC
        let legacyTx = nextTxId()
        let legacyPacket = PTPPacket.buildCommand(opCode: .getDevicePropValue, txId: legacyTx, params: [0xD1AC])
        let (legacyData, legacyContainer) = try await camera.requestSendPTPCommand(legacyPacket, outData: nil)
        let legacyResp = parseResponseCode(from: legacyContainer)
        
        if legacyResp == PTPResponseCode.ok.rawValue && legacyData.count >= 4 {
            let count = legacyData.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self) }
            let shutterCount = UInt32(littleEndian: count)
            let modelInfo = CanonModelDatabase.lookup(name: camera.name ?? "")
            logger("Canon 標準屬性 (0xD1AC) 讀取成功: \(shutterCount)")
            return ShutterReport(
                cameraName: camera.name ?? "Canon DSLR",
                brand: .canon,
                serialNumber: camera.serialNumberString ?? "N/A",
                shutterCount: shutterCount,
                mirrorCount: nil,
                totalActuations: nil,
                ratedLife: modelInfo.ratedLife,
                readingMethod: .ptpLegacy,
                timestamp: Date()
            )
        }
        
        // Step 2: Modern MPU Channel (0x9052)
        logger("屬性未開放，啟用 Canon MPU 監控通道 (0x9052)...")
        let modelInfo = CanonModelDatabase.lookup(name: camera.name ?? "")
        let shutterAddr = modelInfo.mpuShutterAddress ?? 0x1001
        let mirrorAddr = modelInfo.mpuMirrorAddress ?? 0x100B
        let totalAddr = modelInfo.mpuTotalAddress ?? 0x1015
        
        // MonOpen
        let openPayload = try CanonFactoryPayload.buildCommand(name: "MonOpen")
        let openCmd = PTPPacket.buildCommand(opCode: .canonFactorySend, txId: nextTxId(), params: [0, 0])
        logger("發送 MonOpen 叫醒 MPU...")
        _ = try await camera.requestSendPTPCommand(openCmd, outData: openPayload)
        
        // MonClose on exit
        defer {
            Task {
                logger("安全關閉 MPU 監控 (MonClose)...")
                if let closePayload = try? CanonFactoryPayload.buildCommand(name: "MonClose") {
                    let closeCmd = PTPPacket.buildCommand(opCode: .canonFactorySend, txId: nextTxId(), params: [0, 0])
                    _ = try? await camera.requestSendPTPCommand(closeCmd, outData: closePayload)
                }
            }
        }
        
        // MonReadAndGetData (Shutter)
        let shutterRaw = try await readMPU(camera: camera, address: shutterAddr, length: 10, nextTxId: nextTxId)
        guard let shutterCount = CanonFactoryPayload.decodeCounter(from: [UInt8](shutterRaw)) else {
            throw NSError(domain: "CanonPTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "解碼 Canon MPU 快門計數失敗"])
        }
        
        // Mirror & Total
        var mirrorCount: UInt32? = nil
        if let mirrorRaw = try? await readMPU(camera: camera, address: mirrorAddr, length: 10, nextTxId: nextTxId) {
            mirrorCount = CanonFactoryPayload.decodeCounter(from: [UInt8](mirrorRaw))
        }
        var totalCount: UInt32? = nil
        if let totalRaw = try? await readMPU(camera: camera, address: totalAddr, length: 10, nextTxId: nextTxId) {
            totalCount = CanonFactoryPayload.decodeCounter(from: [UInt8](totalRaw))
        }
        
        return ShutterReport(
            cameraName: camera.name ?? modelInfo.name,
            brand: .canon,
            serialNumber: camera.serialNumberString ?? "N/A",
            shutterCount: shutterCount,
            mirrorCount: mirrorCount,
            totalActuations: totalCount,
            ratedLife: modelInfo.ratedLife,
            readingMethod: .ptpMpuMonitor,
            timestamp: Date()
        )
    }
    
    private func readMPU(camera: ICCameraDevice, address: UInt32, length: UInt32, nextTxId: () -> UInt32) async throws -> Data {
        let readPayload = try CanonFactoryPayload.buildCommand(name: "MonReadAndGetData", args: [
            .init(tag: 2, value: 2),
            .init(tag: 2, value: address),
            .init(tag: 2, value: length)
        ])
        let sendCmd = PTPPacket.buildCommand(opCode: .canonFactorySend, txId: nextTxId(), params: [0, 1])
        _ = try await camera.requestSendPTPCommand(sendCmd, outData: readPayload)
        
        let recvCmd = PTPPacket.buildCommand(opCode: .canonFactoryRecv, txId: nextTxId(), params: [0, 0, 1])
        let (replyData, replyContainer) = try await camera.requestSendPTPCommand(recvCmd, outData: nil)
        let respCode = parseResponseCode(from: replyContainer)
        guard respCode == PTPResponseCode.ok.rawValue else {
            throw NSError(domain: "CanonPTP", code: Int(respCode), userInfo: [NSLocalizedDescriptionKey: "MPU Read failed"])
        }
        return replyData
    }
    
    private func parseResponseCode(from container: Data) -> UInt16 {
        guard container.count >= 8 else { return 0x2002 }
        let code = container.subdata(in: 6..<8).withUnsafeBytes { $0.load(as: UInt16.self) }
        return UInt16(littleEndian: code)
    }
}

// MARK: - 2. Nikon Driver
public struct NikonDriver: CameraDriver {
    public let brand: CameraBrand = .nikon
    
    public init() {}
    
    public func canHandle(deviceName: String, manufacturer: String?) -> Bool {
        CameraBrand.detect(from: deviceName, manufacturer: manufacturer) == .nikon
    }
    
    public func readShutter(
        camera: ICCameraDevice,
        nextTxId: @escaping @Sendable () -> UInt32,
        logger: @escaping @Sendable (String) -> Void
    ) async throws -> ShutterReport {
        logger("偵測到 Nikon 相機，發送 Nikon PTP 查詢屬性 (0xD100)...")
        
        let txId = nextTxId()
        // Nikon Property 0xD100 (Shutter Count) via standard GetDevicePropValue
        let packet = PTPPacket.buildCommand(opCode: .getDevicePropValue, txId: txId, params: [0xD100])
        let (data, container) = try await camera.requestSendPTPCommand(packet, outData: nil)
        
        guard container.count >= 8 else {
            throw NSError(domain: "NikonPTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Nikon PTP 回傳封包無效"])
        }
        
        let respCode = container.subdata(in: 6..<8).withUnsafeBytes { $0.load(as: UInt16.self) }
        guard UInt16(littleEndian: respCode) == PTPResponseCode.ok.rawValue, data.count >= 4 else {
            throw NSError(domain: "NikonPTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Nikon 未開放此屬性或讀取失敗"])
        }
        
        let count = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self) }
        let shutterCount = UInt32(littleEndian: count)
        
        logger("Nikon 快門數讀取成功: \(shutterCount)")
        return ShutterReport(
            cameraName: camera.name ?? "Nikon Camera",
            brand: .nikon,
            serialNumber: camera.serialNumberString ?? "N/A",
            shutterCount: shutterCount,
            mirrorCount: nil,
            totalActuations: nil,
            ratedLife: 200_000,
            readingMethod: .ptpLegacy,
            timestamp: Date()
        )
    }
}

// MARK: - 3. Sony Driver
public struct SonyDriver: CameraDriver {
    public let brand: CameraBrand = .sony
    
    public init() {}
    
    public func canHandle(deviceName: String, manufacturer: String?) -> Bool {
        CameraBrand.detect(from: deviceName, manufacturer: manufacturer) == .sony
    }
    
    public func readShutter(
        camera: ICCameraDevice,
        nextTxId: @escaping @Sendable () -> UInt32,
        logger: @escaping @Sendable (String) -> Void
    ) async throws -> ShutterReport {
        logger("偵測到 Sony 相機，建議使用直接拖曳 ARW/JPG 檔案快速檢測...")
        
        // Sony cameras store shutter counts in EXIF MakerNotes by default
        throw NSError(domain: "SonyPTP", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Sony 機型建議直接拖曳任一張最新拍攝的 ARW 或 JPG 照片至視窗中即可即刻讀出！"
        ])
    }
}
