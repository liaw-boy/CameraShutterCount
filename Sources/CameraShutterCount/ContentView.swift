import SwiftUI
import UniformTypeIdentifiers
import CameraShutterCore

public struct ContentView: View {
    @StateObject private var cameraManager = CameraManager.shared
    @State private var isTargetedForDrop = false
    @State private var showLog = false
    @State private var selectedSimBrand: CameraBrand = .canon
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    if let report = cameraManager.currentReport {
                        shutterReportView(report: report)
                        compactDropHint
                    } else if cameraManager.isConnected {
                        connectedWaitingView
                    } else {
                        disconnectedStateView
                        standardDropZone
                    }
                    
                    if showLog {
                        activityLogView
                    }
                }
                .padding(20)
            }
            
            Divider()
            footerView
        }
        .frame(minWidth: 500, idealWidth: 540, minHeight: 520, idealHeight: 560)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(brandColor(for: cameraManager.detectedBrand).opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(brandColor(for: cameraManager.detectedBrand))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(appTitle)
                    .font(.system(size: 14, weight: .bold))
                Text("專業相機快門檢測工具")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Connection Status Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(cameraManager.isConnected ? Color.green : Color.gray.opacity(0.6))
                    .frame(width: 7, height: 7)
                Text(cameraManager.isConnected ? "相機已連線" : "等待連線")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(cameraManager.isConnected ? .primary : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
            
            if cameraManager.isConnected {
                Button(action: {
                    cameraManager.isConnected = false
                    cameraManager.connectedCamera = nil
                    cameraManager.currentReport = nil
                    cameraManager.cameraName = "未連接相機"
                    cameraManager.detectedBrand = .generic
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("中斷連線")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
    
    private var appTitle: String {
        if cameraManager.isConnected && cameraManager.detectedBrand != .generic {
            return "\(cameraManager.detectedBrand.rawValue) Shutter Count"
        }
        return "Camera Shutter Count"
    }
    
    private func brandColor(for brand: CameraBrand) -> Color {
        switch brand {
        case .canon: return .red
        case .nikon: return .yellow
        case .sony: return .orange
        case .fujifilm: return .green
        default: return .blue
        }
    }
    
    // MARK: - Shutter Report Card
    private func shutterReportView(report: ShutterReport) -> some View {
        VStack(spacing: 16) {
            // Card Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(report.cameraName)
                            .font(.system(size: 18, weight: .bold))
                        
                        Text(report.brand.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(brandColor(for: report.brand).opacity(0.15)))
                            .foregroundColor(brandColor(for: report.brand))
                    }
                    Text("機身序號: \(report.serialNumber)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text(report.readingMethod.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.textBackgroundColor)))
            }
            
            Divider()
            
            // Hero Number Section
            VStack(spacing: 6) {
                Text("累計快門擊發數")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(formattedNumber(report.shutterCount))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            
            // Durability Gauge
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("原廠額定壽命: \(formattedNumber(report.ratedLife)) 次")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("已消耗 \(String(format: "%.1f", report.lifePercentage * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(progressColor(for: report.lifePercentage))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.18))
                            .frame(height: 8)
                        Capsule()
                            .fill(progressColor(for: report.lifePercentage))
                            .frame(width: max(0, min(geo.size.width * CGFloat(report.lifePercentage), geo.size.width)), height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            // Balanced 3-Tile Grid
            HStack(spacing: 10) {
                if let mirror = report.mirrorCount {
                    statTile(title: "反光鏡作動", value: "\(formattedNumber(mirror)) 次")
                } else {
                    statTile(title: "機械快門類型", value: "電子/機械混合")
                }
                
                if let total = report.totalActuations {
                    statTile(title: "總計曝光", value: "\(formattedNumber(total)) 次")
                }
                
                let remaining = report.ratedLife > report.shutterCount ? (report.ratedLife - report.shutterCount) : 0
                statTile(title: "預估剩餘壽命", value: "\(formattedNumber(remaining)) 次")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }
    
    private func statTile(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.textBackgroundColor)))
    }
    
    private func formattedNumber(_ n: UInt32) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    private func progressColor(for percentage: Double) -> Color {
        if percentage < 0.5 { return .green }
        if percentage < 0.8 { return .orange }
        return .red
    }
    
    // MARK: - Compact Drop Hint (When report is displayed)
    private var compactDropHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.badge.arrow.down")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("拖曳其他 RAW 或 JPEG 照片至此切換檢測")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isTargetedForDrop ? Color.blue : Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4]))
                .background(RoundedRectangle(cornerRadius: 8).fill(isTargetedForDrop ? Color.blue.opacity(0.05) : Color.clear))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Standard Drop Zone (When disconnected)
    private var standardDropZone: some View {
        VStack(spacing: 6) {
            Image(systemName: "photo.badge.arrow.down")
                .font(.system(size: 22))
                .foregroundColor(isTargetedForDrop ? .blue : .secondary)
            
            Text("免傳輸線？直接拖曳照片至此檢測")
                .font(.system(size: 12, weight: .medium))
            
            Text("支援 Canon (.CR3/.CR2)、Nikon (.NEF/.JPG)、Sony (.ARW/.JPG)、Fujifilm (.RAF)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargetedForDrop ? Color.blue : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.2, dash: [5]))
                .background(RoundedRectangle(cornerRadius: 10).fill(isTargetedForDrop ? Color.blue.opacity(0.05) : Color.clear))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                Task {
                    if let report = await UniversalFileParser.parse(fileURL: url) {
                        await MainActor.run {
                            self.cameraManager.currentReport = report
                            self.cameraManager.detectedBrand = report.brand
                        }
                    }
                }
            }
        }
        return true
    }
    
    // MARK: - Connected Waiting State
    private var connectedWaitingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.0)
            Text("正在向 \(cameraManager.detectedBrand.rawValue) 相機發送 PTP 指令讀取快門...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
    }
    
    // MARK: - Disconnected State
    private var disconnectedStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "cable.connector")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("等待相機連線")
                    .font(.system(size: 15, weight: .bold))
                Text("支援各大品牌相機：Canon、Nikon、Sony、Fujifilm 等")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 10) {
                stepItem(number: 1, text: "關閉相機 Wi-Fi")
                stepItem(number: 2, text: "插上傳輸線")
                stepItem(number: 3, text: "開啟相機電源")
            }
            .padding(.top, 4)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Multi-Brand Simulation Buttons
            VStack(spacing: 6) {
                Text("模擬各品牌相機通訊測試:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    simButton(title: "Canon 5D4", brand: .canon)
                    simButton(title: "Nikon Z8", brand: .nikon)
                    simButton(title: "Sony A7 IV", brand: .sony)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func simButton(title: String, brand: CameraBrand) -> some View {
        Button(action: {
            cameraManager.simulateDevice(brand: brand)
        }) {
            HStack(spacing: 4) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .buttonStyle(.bordered)
    }
    
    private func stepItem(number: Int, text: String) -> some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
    }
    
    // MARK: - Activity Log
    private var activityLogView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("通訊底層即時日誌")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Button("清空") {
                    cameraManager.logMessages.removeAll()
                }
                .font(.system(size: 10))
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(cameraManager.logMessages, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.1)))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Button(action: { showLog.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                    Text(showLog ? "隱藏日誌" : "查看日誌")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            Spacer()
            
            if let report = cameraManager.currentReport {
                Button("複製報告") {
                    let text = """
                    品牌: \(report.brand.rawValue)
                    型號: \(report.cameraName)
                    序號: \(report.serialNumber)
                    快門擊發次數: \(report.shutterCount)
                    額定快門壽命: \(report.ratedLife) (\(Int(report.lifePercentage * 100))%)
                    讀取途徑: \(report.readingMethod.rawValue)
                    檢查時間: \(report.timestamp)
                    """
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .buttonStyle(.bordered)
            }
            
            Button("重新讀取") {
                Task {
                    await cameraManager.readShutterCount()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(brandColor(for: cameraManager.detectedBrand))
            .disabled(!cameraManager.isConnected || cameraManager.isReading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}
