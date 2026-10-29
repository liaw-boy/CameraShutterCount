import Foundation
import ImageCaptureCore
import CameraShutterCore

public class CameraManager: NSObject, ObservableObject {
    public static let shared = CameraManager()
    
    @Published public var connectedCamera: ICCameraDevice?
    @Published public var cameraName: String = "未連接相機"
    @Published public var detectedBrand: CameraBrand = .generic
    @Published public var isConnected: Bool = false
    @Published public var isReading: Bool = false
    @Published public var currentReport: ShutterReport?
    @Published public var errorMessage: String?
    @Published public var logMessages: [String] = []
    @Published public var history: [ShutterReport] = []
    
    private var deviceBrowser: ICDeviceBrowser!
    private var transactionCounter: UInt32 = 1
    private let historyKey = "CameraShutterCount_History_v1"
    
    public override init() {
        super.init()
        self.deviceBrowser = ICDeviceBrowser()
        self.deviceBrowser.delegate = self
        self.deviceBrowser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: ICDeviceTypeMask.camera.rawValue)!
        self.deviceBrowser.start()
        loadHistory()
        log("相機通訊中樞已就緒，ImageCaptureCore 正在監聽 USB 埠...")
    }
    
    public func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(message)"
        Task { @MainActor in
            self.logMessages.append(logLine)
        }
        print(logLine)
    }
    
    public func nextTxId() -> UInt32 {
        transactionCounter += 1
        return transactionCounter
    }
    
    // MARK: - History Persistence
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let list = try? JSONDecoder().decode([ShutterReport].self, from: data) else {
            return
        }
        self.history = list
    }
    
    public func recordReport(_ report: ShutterReport) {
        // Remove duplicate if same serial and count
        history.removeAll { $0.serialNumber == report.serialNumber && $0.shutterCount == report.shutterCount }
        history.insert(report, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    public func clearHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: historyKey)
        log("已清空本地檢測歷史紀錄。")
    }
    
    // MARK: - Simulation / Demo Mode (Multi-Brand Support)
    public func simulateDevice(brand: CameraBrand = .canon) {
        let modelName: String
        let shutterCount: UInt32
        let ratedLife: UInt32
        let serial: String
        
        switch brand {
        case .canon:
            modelName = "Canon EOS 5D Mark IV"
            shutterCount = 26_374
            ratedLife = 150_000
            serial = "SN-CANON-08204"
        case .nikon:
            modelName = "Nikon Z8"
            shutterCount = 14_820
            ratedLife = 400_000
            serial = "SN-NIKON-93105"
        case .sony:
            modelName = "Sony Alpha 7 IV"
            shutterCount = 38_910
            ratedLife = 200_000
            serial = "SN-SONY-66281"
        case .fujifilm:
            modelName = "Fujifilm X-T5"
            shutterCount = 18_450
            ratedLife = 150_000
            serial = "SN-FUJI-42901"
        default:
            modelName = "Pentax K-1 Mark II"
            shutterCount = 42_100
            ratedLife = 300_000
            serial = "SN-PENTAX-1104"
        }
        
        log("啟動 [\(brand.rawValue)] 模擬測試: \(modelName)...")
        
        Task { @MainActor in
            self.isConnected = true
            self.cameraName = modelName
            self.detectedBrand = brand
            self.isReading = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.log("發送 PTP 0x1001 GetDeviceInfo: 識別製造商為 \(brand.rawValue)")
            self.log("配對 \(brand.rawValue)Driver 硬體專屬驅動模組...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if brand == .canon {
                self.log("發送 MonOpen (0x9052, sub 0x0020) 叫醒 Canon MPU...")
                self.log("讀取 MPU 位址 0x1001，解碼快門數: \(shutterCount)")
                self.log("發送 MonClose (0x9053) 安全釋放 MPU 監控...")
            } else if brand == .nikon {
                self.log("發送 Nikon PTP 屬性 0xD100 查詢...")
                self.log("Nikon PTP 回傳成功，快門數: \(shutterCount)")
            } else if brand == .sony {
                self.log("讀取 Sony EXIF/PTP 遙測標籤，快門數: \(shutterCount)")
            } else if brand == .fujifilm {
                self.log("解析 Fujifilm RAF MakerNotes 快門標記: \(shutterCount)")
            } else {
                self.log("讀取通用 PTP 標記，快門數: \(shutterCount)")
            }
            
            Task { @MainActor in
                let rep = ShutterReport(
                    cameraName: modelName,
                    brand: brand,
                    serialNumber: serial,
                    shutterCount: shutterCount,
                    mirrorCount: brand == .canon ? (shutterCount - 226) : nil,
                    totalActuations: shutterCount + 120,
                    ratedLife: ratedLife,
                    readingMethod: brand == .canon ? .ptpMpuMonitor : (brand == .nikon ? .ptpNikon : .exifFile),
                    timestamp: Date()
                )
                self.currentReport = rep
                self.recordReport(rep)
                self.isReading = false
            }
        }
    }
    
    // MARK: - Read Execution (Multi-Brand Dispatch)
    public func readShutterCount() async {
        guard let camera = connectedCamera else {
            await MainActor.run {
                self.errorMessage = "未偵測到 USB 相機連線。"
            }
            return
        }
        
        let name = camera.name ?? "Unknown Device"
        let brand = CameraBrand.detect(from: name)
        
        await MainActor.run {
            self.isReading = true
            self.errorMessage = nil
            self.detectedBrand = brand
        }
        log("正在向 [\(brand.rawValue)] 裝置 \(name) 發起快門查詢...")
        
        guard let driver = CameraDriverRegistry.shared.findDriver(deviceName: name, manufacturer: nil) else {
            await MainActor.run {
                self.errorMessage = "目前尚未支援 \(brand.rawValue) 該機型的 USB 連線協議，建議直接拖曳 RAW 照片檢測。"
                self.isReading = false
            }
            log("找不到適配的相機驅動: \(name)")
            return
        }
        
        do {
            let report = try await driver.readShutter(
                camera: camera,
                nextTxId: { self.nextTxId() },
                logger: { self.log($0) }
            )
            await MainActor.run {
                self.currentReport = report
                self.recordReport(report)
                self.isReading = false
            }
            log("快門數讀取成功: \(report.shutterCount) 次")
        } catch {
            await MainActor.run {
                self.errorMessage = "讀取快門數失敗: \(error.localizedDescription)"
                self.isReading = false
            }
            log("讀取失敗: \(error.localizedDescription)")
        }
    }
}

// MARK: - ICDeviceBrowserDelegate & ICCameraDeviceDelegate
extension CameraManager: ICDeviceBrowserDelegate, ICCameraDeviceDelegate {
    public func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        log("偵測到相機裝置接入: \(device.name ?? "Unknown")")
        if let camera = device as? ICCameraDevice {
            self.connectedCamera = camera
            self.cameraName = camera.name ?? "Camera"
            self.detectedBrand = CameraBrand.detect(from: cameraName)
            self.isConnected = true
            camera.delegate = self
            camera.requestOpenSession()
            log("正在開啟相機連線通訊工作階段...")
        }
    }
    
    public func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        log("相機已拔除中斷: \(device.name ?? "Unknown")")
        if self.connectedCamera == device {
            Task { @MainActor in
                self.connectedCamera = nil
                self.cameraName = "未連接相機"
                self.detectedBrand = .generic
                self.isConnected = false
                self.currentReport = nil
            }
        }
    }
    
    public func deviceDidBecomeReady(_ device: ICDevice) {
        guard let camera = device as? ICCameraDevice else { return }
        log("相機通訊通道已就緒: \(camera.name ?? "")")
        Task { @MainActor in
            self.isConnected = true
            self.cameraName = camera.name ?? "相機裝置"
            await self.readShutterCount()
        }
    }
    
    public func device(_ device: ICDevice, didOpenSessionWithError error: (any Error)?) {
        if let error = error {
            self.log("開啟相機通訊會話失敗: \(error.localizedDescription)")
            Task { @MainActor in
                self.errorMessage = "連線錯誤: \(error.localizedDescription)"
            }
        }
    }
    
    public func device(_ device: ICDevice, didCloseSessionWithError error: (any Error)?) {
        self.log("相機通訊會話已關閉。")
        Task { @MainActor in
            self.isConnected = false
        }
    }
    
    public func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {}
    public func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {}
    public func cameraDevice(_ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?, for item: ICCameraItem, error: (any Error)?) {}
    public func cameraDevice(_ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable : Any]?, for item: ICCameraItem, error: (any Error)?) {}
    public func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {}
    public func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {}
    public func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {}
    public func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {}
    public func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {}
    public func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {}
    public func didRemove(_ device: ICDevice) {}
}
