import SwiftUI
import UniformTypeIdentifiers
import AppKit
import CameraShutterCore

public struct ContentView: View {
    @StateObject private var cameraManager = CameraManager.shared
    @State private var selectedTab: AppTab = .inspection
    @State private var isTargetedForDrop = false
    @State private var showLog = false
    @State private var dbSearchText = ""
    @State private var dbSelectedBrand: CameraBrand? = nil
    @State private var copiedNotice = false
    
    public init() {}
    
    public enum AppTab: String, CaseIterable, Identifiable {
        case inspection = "儀表檢測"
        case database = "型號壽命庫"
        case history = "檢測紀錄"
        
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .inspection: return "gauge.with.needle"
            case .database: return "books.vertical"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            tabSelectorView
            Divider()
            
            ZStack {
                switch selectedTab {
                case .inspection:
                    inspectionTabView
                case .database:
                    databaseTabView
                case .history:
                    historyTabView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            footerView
        }
        .frame(minWidth: 540, idealWidth: 580, minHeight: 650, idealHeight: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(brandColor(for: cameraManager.detectedBrand).opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: "camera.metering.matrix")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(brandColor(for: cameraManager.detectedBrand))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(appTitle)
                    .font(.system(size: 14, weight: .bold))
                Text("專業相機快門檢測與壽命分析工具")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Connection Status Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(cameraManager.isConnected ? Color.green : Color.gray.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text(cameraManager.isConnected ? "相機已連線" : "等待相機接入")
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
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Selector Bar
    private var tabSelectorView: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 11, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .bold : .regular))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(selectedTab == tab ? Color(NSColor.controlAccentColor).opacity(0.16) : Color.clear)
                    )
                    .foregroundColor(selectedTab == tab ? Color(NSColor.controlAccentColor) : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            
            // Quick File Open Button
            Button(action: openFileDialog) {
                HStack(spacing: 4) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 11))
                    Text("選取照片檔案")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
            }
            .buttonStyle(.plain)
            .help("手動選擇 RAW 或 JPEG 照片進行快門檢測")
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
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
    
    // =========================================================================
    // MARK: - Tab 1: Inspection View
    // =========================================================================
    private var inspectionTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let report = cameraManager.currentReport {
                    shutterReportCard(report: report)
                    compactDropZone
                } else if cameraManager.isConnected {
                    connectedWaitingView
                } else {
                    hardwareMonitorBanner
                    brandSupportBadgeBar
                    connectionStepsCard
                    multiBrandSimulationSection
                    standardDropZone
                }
                
                if showLog {
                    activityLogView
                }
            }
            .padding(18)
        }
    }
    
    // MARK: - Hardware Monitor Banner
    private var hardwareMonitorBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.18))
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("USB 監控通訊通道運作中")
                        .font(.system(size: 12, weight: .bold))
                    Text("PTP / MPU 唯讀防護已就緒")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.blue.opacity(0.12)))
                        .foregroundColor(.blue)
                }
                Text("隨插即用自動辨識 • 拒絕任何寫入指令 • 安全釋放工作階段")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1))
        )
    }
    
    // MARK: - Brand Support Badge Bar
    private var brandSupportBadgeBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("支援品牌與通訊協定")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                brandChip(brand: "Canon", protocols: "MPU / PTP / CR3", color: .red)
                brandChip(brand: "Nikon", protocols: "PTP 0xD100 / NEF", color: .yellow)
                brandChip(brand: "Sony", protocols: "ARW / MakerNotes", color: .orange)
                brandChip(brand: "Fujifilm", protocols: "RAF / EXIF", color: .green)
                brandChip(brand: "Pentax", protocols: "DNG / PEF", color: .blue)
            }
        }
    }
    
    private func brandChip(brand: String, protocols: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(brand)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            Text(protocols)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - Connection Steps Card
    private var connectionStepsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "cable.connector.horizontal")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("相機連線指南")
                        .font(.system(size: 13, weight: .bold))
                    Text("請確認退出原廠相機管理軟體 (如 EOS Utility、NX Studio)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            HStack(spacing: 8) {
                stepBadge(number: 1, title: "關閉 Wi-Fi", sub: "釋放相機 USB 埠")
                stepBadge(number: 2, title: "連接傳輸線", sub: "使用高速 USB 線")
                stepBadge(number: 3, title: "開啟相機電源", sub: "切換開關至 ON")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func stepBadge(number: Int, title: String, sub: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 22, height: 22)
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(NSColor.textBackgroundColor)))
    }
    
    // MARK: - Multi-Brand Simulation
    private var multiBrandSimulationSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("快速模擬各廠牌通訊測試:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 8) {
                simButton(title: "Canon 5D4", brand: .canon)
                simButton(title: "Nikon Z8", brand: .nikon)
                simButton(title: "Sony A7 IV", brand: .sony)
                simButton(title: "Fuji X-T5", brand: .fujifilm)
                simButton(title: "Pentax K-1", brand: .generic)
            }
        }
    }
    
    private func simButton(title: String, brand: CameraBrand) -> some View {
        Button(action: { cameraManager.simulateDevice(brand: brand) }) {
            HStack(spacing: 4) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
        .buttonStyle(.bordered)
    }
    
    // MARK: - Standard Drop Zone
    private var standardDropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.arrow.down")
                .font(.system(size: 26))
                .foregroundColor(isTargetedForDrop ? .blue : .secondary)
            
            Text("免傳輸線？直接拖曳照片至此快速檢測")
                .font(.system(size: 13, weight: .bold))
            
            Text("支援相機拍攝之最新原始照片，無損即時解析快門次數中繼資料")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            HStack(spacing: 6) {
                formatPill("Canon .CR3 / .CR2")
                formatPill("Nikon .NEF")
                formatPill("Sony .ARW")
                formatPill("Fuji .RAF")
                formatPill("JPG")
            }
            .padding(.top, 2)
            
            Button("點擊選取檔案...") {
                openFileDialog()
            }
            .buttonStyle(.link)
            .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargetedForDrop ? Color.blue : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .background(RoundedRectangle(cornerRadius: 10).fill(isTargetedForDrop ? Color.blue.opacity(0.06) : Color.clear))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func formatPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(NSColor.controlBackgroundColor)))
            .foregroundColor(.secondary)
    }
    
    // MARK: - Shutter Report Card (When Connected)
    private func shutterReportCard(report: ShutterReport) -> some View {
        VStack(spacing: 16) {
            // Header
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
                        
                        // Health Badge
                        Text(report.healthRating)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(progressColor(for: report.lifePercentage).opacity(0.18)))
                            .foregroundColor(progressColor(for: report.lifePercentage))
                    }
                    
                    HStack(spacing: 6) {
                        Text("機身序號: \(report.serialNumber)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(report.serialNumber, forType: .string)
                            copiedNotice = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedNotice = false }
                        }) {
                            Image(systemName: copiedNotice ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("複製機身序號")
                    }
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text(report.readingMethod.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.textBackgroundColor)))
            }
            
            Divider()
            
            // Hero Gauge & Big Number
            HStack(spacing: 24) {
                // Circular Gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.18), lineWidth: 10)
                        .frame(width: 86, height: 86)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(report.lifePercentage))
                        .stroke(progressColor(for: report.lifePercentage), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 86, height: 86)
                    
                    VStack(spacing: 0) {
                        Text("\(Int(report.lifePercentage * 100))%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("已耗損")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("累計快門擊發次數")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(formattedNumber(report.shutterCount))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            
            // Linear Durability Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("原廠額定壽命: \(formattedNumber(report.ratedLife)) 次")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    let remaining = report.ratedLife > report.shutterCount ? (report.ratedLife - report.shutterCount) : 0
                    Text("預估剩餘: \(formattedNumber(remaining)) 次")
                        .font(.system(size: 11, weight: .bold))
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
            
            // 4-Tile Grid
            HStack(spacing: 8) {
                statTile(title: "機械快門釋放", value: "\(formattedNumber(report.shutterCount)) 次")
                
                if let mirror = report.mirrorCount {
                    statTile(title: "反光鏡作動", value: "\(formattedNumber(mirror)) 次")
                } else {
                    statTile(title: "快門架構", value: "電子/機械混合")
                }
                
                let remaining = report.ratedLife > report.shutterCount ? (report.ratedLife - report.shutterCount) : 0
                statTile(title: "預估剩餘", value: "\(formattedNumber(remaining)) 次")
                statTile(title: "原廠基準", value: "\(formattedNumber(report.ratedLife)) 次")
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
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(NSColor.textBackgroundColor)))
    }
    
    private var compactDropZone: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.badge.arrow.down")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("拖曳其他照片至此快速切換檢測")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Button("瀏覽檔案...") { openFileDialog() }
                .font(.system(size: 11))
                .buttonStyle(.link)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isTargetedForDrop ? Color.blue : Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { handleDrop(providers: $0) }
    }
    
    // =========================================================================
    // MARK: - Tab 2: Database View
    // =========================================================================
    private var databaseTabView: some View {
        VStack(spacing: 12) {
            // Search Bar & Filter Bar
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("搜尋相機型號，如 5D4, Z8, A7, R5, X-T5...", text: $dbSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !dbSearchText.isEmpty {
                        Button(action: { dbSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                
                // Brand Filter Pills
                HStack(spacing: 4) {
                    dbBrandFilterBtn(title: "全部", brand: nil)
                    dbBrandFilterBtn(title: "Canon", brand: .canon)
                    dbBrandFilterBtn(title: "Nikon", brand: .nikon)
                    dbBrandFilterBtn(title: "Sony", brand: .sony)
                    dbBrandFilterBtn(title: "Fuji", brand: .fujifilm)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            
            // Models List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredModels) { model in
                        cameraDatabaseRow(model: model)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }
    
    private func dbBrandFilterBtn(title: String, brand: CameraBrand?) -> some View {
        Button(action: { dbSelectedBrand = brand }) {
            Text(title)
                .font(.system(size: 11, weight: dbSelectedBrand == brand ? .bold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(dbSelectedBrand == brand ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
                )
                .foregroundColor(dbSelectedBrand == brand ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    private var filteredModels: [CameraModelInfo] {
        CameraModelDatabase.allModels.filter { model in
            let matchesBrand = (dbSelectedBrand == nil || model.brand == dbSelectedBrand)
            let matchesSearch = dbSearchText.isEmpty || model.name.localizedCaseInsensitiveContains(dbSearchText)
            return matchesBrand && matchesSearch
        }
    }
    
    private func cameraDatabaseRow(model: CameraModelInfo) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(brandColor(for: model.brand).opacity(0.16))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "camera")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(brandColor(for: model.brand))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.system(size: 13, weight: .bold))
                    Text(model.brand.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(brandColor(for: model.brand).opacity(0.12)))
                        .foregroundColor(brandColor(for: model.brand))
                }
                Text(model.shutterType)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(formattedNumber(model.ratedLife)) 次")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("原廠額定壽命")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // =========================================================================
    // MARK: - Tab 3: History View
    // =========================================================================
    private var historyTabView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("共 \(cameraManager.history.count) 筆檢測紀錄")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if !cameraManager.history.isEmpty {
                    Button("清除所有紀錄") {
                        cameraManager.clearHistory()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            
            if cameraManager.history.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("目前尚無快門檢測紀錄")
                        .font(.system(size: 13, weight: .bold))
                    Text("當您透過 USB 讀取或拖曳照片檢測時，紀錄將自動保存於此。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(cameraManager.history) { item in
                            historyRow(report: item)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
        }
    }
    
    private func historyRow(report: ShutterReport) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(report.cameraName)
                        .font(.system(size: 13, weight: .bold))
                    Text(report.healthRating)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(progressColor(for: report.lifePercentage).opacity(0.18)))
                        .foregroundColor(progressColor(for: report.lifePercentage))
                }
                Text("序號: \(report.serialNumber) • \(DateFormatter.localizedString(from: report.timestamp, dateStyle: .short, timeStyle: .short))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(formattedNumber(report.shutterCount)) 次")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("已耗損 \(Int(report.lifePercentage * 100))%")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                cameraManager.currentReport = report
                selectedTab = .inspection
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color(NSColor.controlBackgroundColor)))
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Button(action: { showLog.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                    Text(showLog ? "隱藏底層通訊日誌" : "查看底層通訊日誌")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            Spacer()
            
            if let report = cameraManager.currentReport {
                Button("匯出檢測證明") { exportCertificate(report: report) }
                    .buttonStyle(.bordered)
                
                Button("複製報告") { copyReport(report: report) }
                    .buttonStyle(.bordered)
            }
            
            Button("重新讀取") {
                Task { await cameraManager.readShutterCount() }
            }
            .buttonStyle(.borderedProminent)
            .tint(brandColor(for: cameraManager.detectedBrand))
            .disabled(!cameraManager.isConnected || cameraManager.isReading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
    
    // MARK: - Helpers
    private func formattedNumber(_ n: UInt32) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    private func progressColor(for percentage: Double) -> Color {
        if percentage < 0.35 { return .green }
        if percentage < 0.70 { return .orange }
        return .red
    }
    
    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "cr3") ?? .data,
            UTType(filenameExtension: "cr2") ?? .data,
            UTType(filenameExtension: "nef") ?? .data,
            UTType(filenameExtension: "arw") ?? .data,
            UTType(filenameExtension: "raf") ?? .data,
            UTType(filenameExtension: "dng") ?? .data,
            .jpeg,
            .tiff
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                if let report = await UniversalFileParser.parse(fileURL: url) {
                    await MainActor.run {
                        self.cameraManager.currentReport = report
                        self.cameraManager.detectedBrand = report.brand
                        self.cameraManager.recordReport(report)
                        self.selectedTab = .inspection
                    }
                }
            }
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
                            self.cameraManager.recordReport(report)
                            self.selectedTab = .inspection
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func copyReport(report: ShutterReport) {
        let text = """
        【Camera Shutter Count 檢測證明】
        相機品牌: \(report.brand.rawValue)
        機身型號: \(report.cameraName)
        機身序號: \(report.serialNumber)
        快門次數: \(formattedNumber(report.shutterCount)) 次
        原廠壽命: \(formattedNumber(report.ratedLife)) 次
        磨損比例: \(String(format: "%.1f", report.lifePercentage * 100))% (\(report.healthRating))
        檢測途徑: \(report.readingMethod.rawValue)
        檢測時間: \(DateFormatter.localizedString(from: report.timestamp, dateStyle: .medium, timeStyle: .medium))
        安全防護: 唯讀通訊 (未變更任何相機暫存器)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func exportCertificate(report: ShutterReport) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "ShutterReport_\(report.cameraName.replacingOccurrences(of: " ", with: "_"))_\(report.serialNumber).txt"
        savePanel.allowedContentTypes = [.plainText]
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let content = """
            ================================================================================
                                CAMERA SHUTTER COUNT INSPECTION CERTIFICATE
                                       相機快門擊發次數與壽命檢驗證明
            ================================================================================
            
            [機身資訊]
            相機品牌: \(report.brand.rawValue)
            機身型號: \(report.cameraName)
            機身序號: \(report.serialNumber)
            檢測時間: \(DateFormatter.localizedString(from: report.timestamp, dateStyle: .long, timeStyle: .medium))
            
            [快門狀態與健康評級]
            累計機械快門擊發數: \(formattedNumber(report.shutterCount)) 次
            原廠設計額定壽命:   \(formattedNumber(report.ratedLife)) 次
            快門耗損比例:       \(String(format: "%.1f", report.lifePercentage * 100))%
            健康狀況評等:       \(report.healthRating)
            
            [通訊協定與安全防護]
            檢測途徑:           \(report.readingMethod.rawValue)
            安全規範:           唯讀防護指令白名單 (未修改 EEPROM / 韌體)
            狀態機釋放:         defer { MonClose } 保證完成釋放
            
            ================================================================================
            Generated by Camera Shutter Count for macOS - Native Inspection Engine
            ================================================================================
            """
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
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
    
    // MARK: - Activity Log View
    private var activityLogView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("底層通訊即時傳輸日誌")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Button("清空") { cameraManager.logMessages.removeAll() }
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
            .frame(height: 90)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.12)))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
    }
}
