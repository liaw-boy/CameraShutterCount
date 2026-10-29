import Foundation

public struct CameraModelInfo: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let brand: CameraBrand
    public let ratedLife: UInt32
    public let shutterType: String
    public let mpuShutterAddress: UInt32?
    public let mpuMirrorAddress: UInt32?
    public let mpuTotalAddress: UInt32?
    
    public init(
        name: String,
        brand: CameraBrand = .canon,
        ratedLife: UInt32,
        shutterType: String = "電子控制縱走式焦平面快門",
        shutterAddr: UInt32? = nil,
        mirrorAddr: UInt32? = nil,
        totalAddr: UInt32? = nil
    ) {
        self.name = name
        self.brand = brand
        self.ratedLife = ratedLife
        self.shutterType = shutterType
        self.mpuShutterAddress = shutterAddr
        self.mpuMirrorAddress = mirrorAddr
        self.mpuTotalAddress = totalAddr
    }
}

public struct ShutterReport: Identifiable, Codable, Sendable {
    public var id: String { "\(serialNumber)-\(timestamp.timeIntervalSince1970)" }
    public let cameraName: String
    public let brand: CameraBrand
    public let serialNumber: String
    public let shutterCount: UInt32
    public let mirrorCount: UInt32?
    public let totalActuations: UInt32?
    public let ratedLife: UInt32
    public let readingMethod: ReadingMethod
    public let timestamp: Date
    
    public init(
        cameraName: String,
        brand: CameraBrand = .canon,
        serialNumber: String,
        shutterCount: UInt32,
        mirrorCount: UInt32? = nil,
        totalActuations: UInt32? = nil,
        ratedLife: UInt32,
        readingMethod: ReadingMethod,
        timestamp: Date = Date()
    ) {
        self.cameraName = cameraName
        self.brand = brand
        self.serialNumber = serialNumber
        self.shutterCount = shutterCount
        self.mirrorCount = mirrorCount
        self.totalActuations = totalActuations
        self.ratedLife = ratedLife
        self.readingMethod = readingMethod
        self.timestamp = timestamp
    }
    
    public var lifePercentage: Double {
        guard ratedLife > 0 else { return 0 }
        return min(Double(shutterCount) / Double(ratedLife), 1.0)
    }
    
    public var healthRating: String {
        let p = lifePercentage
        if p < 0.25 { return "狀態極新" }
        if p < 0.60 { return "狀態良好" }
        if p < 0.85 { return "正常磨損" }
        return "建議保養"
    }
    
    public enum ReadingMethod: String, Codable, Sendable {
        case ptpLegacy = "PTP Standard Property (0xD1AC)"
        case ptpMpuMonitor = "Canon MPU Vendor Channel (0x9052)"
        case ptpNikon = "Nikon PTP Property (0xD100)"
        case cr3MakerNotes = "CR3 RAW MakerNotes"
        case exifFile = "EXIF MakerNotes Metadata"
    }
}

public typealias CanonModelDatabase = CameraModelDatabase

public enum CameraModelDatabase {
    public static let knownModels: [String: CameraModelInfo] = [
        // --- Canon 旗艦與高階專業 DSLR (DIGIC 6/7/8/X MPU Monitor 通道) ---
        "EOS 1D X Mark III": CameraModelInfo(name: "Canon EOS 1D X Mark III", brand: .canon, ratedLife: 500_000, shutterType: "碳纖維簾幕高速機械快門", shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 1D X Mark II": CameraModelInfo(name: "Canon EOS 1D X Mark II", brand: .canon, ratedLife: 400_000, shutterType: "碳纖維簾幕高速機械快門", shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 1D X": CameraModelInfo(name: "Canon EOS 1D X", brand: .canon, ratedLife: 400_000, shutterType: "雙簾機械快門"),
        "EOS 5D Mark IV": CameraModelInfo(name: "Canon EOS 5D Mark IV", brand: .canon, ratedLife: 150_000, shutterType: "電子控制縱走式機械快門", shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 5DS": CameraModelInfo(name: "Canon EOS 5DS", brand: .canon, ratedLife: 150_000, shutterType: "電子控制縱走式機械快門", shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 5DS R": CameraModelInfo(name: "Canon EOS 5DS R", brand: .canon, ratedLife: 150_000, shutterType: "電子控制縱走式機械快門", shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 7D Mark II": CameraModelInfo(name: "Canon EOS 7D Mark II", brand: .canon, ratedLife: 200_000, shutterType: "高速雙馬達機械快門", shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 6D Mark II": CameraModelInfo(name: "Canon EOS 6D Mark II", brand: .canon, ratedLife: 100_000, shutterType: "縱走式焦平面快門", shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 80D": CameraModelInfo(name: "Canon EOS 80D", brand: .canon, ratedLife: 100_000, shutterType: "電子控制縱走式機械快門", shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 90D": CameraModelInfo(name: "Canon EOS 90D", brand: .canon, ratedLife: 120_000, shutterType: "電子控制縱走式機械快門", shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        
        // --- Canon 經典 DSLR (DIGIC 3/4/5 PTP 0xD1AC) ---
        "EOS 5D Mark III": CameraModelInfo(name: "Canon EOS 5D Mark III", brand: .canon, ratedLife: 150_000, shutterType: "電子控制縱走式焦平面快門"),
        "EOS 5D Mark II": CameraModelInfo(name: "Canon EOS 5D Mark II", brand: .canon, ratedLife: 150_000, shutterType: "電子控制縱走式焦平面快門"),
        "EOS 6D": CameraModelInfo(name: "Canon EOS 6D", brand: .canon, ratedLife: 100_000, shutterType: "電子控制縱走式焦平面快門"),
        "EOS 7D": CameraModelInfo(name: "Canon EOS 7D", brand: .canon, ratedLife: 150_000, shutterType: "電子控制縱走式焦平面快門"),
        "EOS 70D": CameraModelInfo(name: "Canon EOS 70D", brand: .canon, ratedLife: 100_000, shutterType: "電子控制縱走式焦平面快門"),
        "EOS 60D": CameraModelInfo(name: "Canon EOS 60D", brand: .canon, ratedLife: 100_000, shutterType: "電子控制縱走式焦平面快門"),
        "EOS 50D": CameraModelInfo(name: "Canon EOS 50D", brand: .canon, ratedLife: 100_000, shutterType: "電子控制縱走式焦平面快門"),
        
        // --- Canon EOS R 無反系列 (CR3 原生中繼資料) ---
        "EOS R3": CameraModelInfo(name: "Canon EOS R3", brand: .canon, ratedLife: 500_000, shutterType: "高速電子與碳纖維機械快門"),
        "EOS R5": CameraModelInfo(name: "Canon EOS R5", brand: .canon, ratedLife: 500_000, shutterType: "電子控制焦平面快門 (含防塵遮簾)"),
        "EOS R5 Mark II": CameraModelInfo(name: "Canon EOS R5 Mark II", brand: .canon, ratedLife: 500_000, shutterType: "高速背照堆疊感應與機械快門"),
        "EOS R6": CameraModelInfo(name: "Canon EOS R6", brand: .canon, ratedLife: 300_000, shutterType: "電子控制焦平面快門"),
        "EOS R6 Mark II": CameraModelInfo(name: "Canon EOS R6 Mark II", brand: .canon, ratedLife: 400_000, shutterType: "電子控制焦平面快門"),
        "EOS R": CameraModelInfo(name: "Canon EOS R", brand: .canon, ratedLife: 200_000, shutterType: "電子控制焦平面快門 (關機遮簾)"),
        "EOS RP": CameraModelInfo(name: "Canon EOS RP", brand: .canon, ratedLife: 100_000, shutterType: "電子前簾與機械快門"),
        "EOS R7": CameraModelInfo(name: "Canon EOS R7", brand: .canon, ratedLife: 200_000, shutterType: "電子控制焦平面快門"),
        "EOS R8": CameraModelInfo(name: "Canon EOS R8", brand: .canon, ratedLife: 100_000, shutterType: "電子前簾與全電子快門"),
        "EOS R10": CameraModelInfo(name: "Canon EOS R10", brand: .canon, ratedLife: 100_000, shutterType: "電子前簾與機械快門"),
        "EOS R50": CameraModelInfo(name: "Canon EOS R50", brand: .canon, ratedLife: 100_000, shutterType: "電子前簾快門"),
        
        // --- Nikon 系列 (PTP 0xD100 / NEF MakerNotes) ---
        "Nikon Z9": CameraModelInfo(name: "Nikon Z9", brand: .nikon, ratedLife: 500_000, shutterType: "純電子超高速快門 (感光元件防護簾)"),
        "Nikon Z8": CameraModelInfo(name: "Nikon Z8", brand: .nikon, ratedLife: 400_000, shutterType: "純電子超高速快門 (感光元件防護簾)"),
        "Nikon Z6 III": CameraModelInfo(name: "Nikon Z6 III", brand: .nikon, ratedLife: 200_000, shutterType: "電子控制縱走式機械焦平面快門"),
        "Nikon Z6 II": CameraModelInfo(name: "Nikon Z6 II", brand: .nikon, ratedLife: 200_000, shutterType: "電子控制縱走式機械焦平面快門"),
        "Nikon Z7 II": CameraModelInfo(name: "Nikon Z7 II", brand: .nikon, ratedLife: 200_000, shutterType: "電子控制縱走式機械焦平面快門"),
        "Nikon Z5": CameraModelInfo(name: "Nikon Z5", brand: .nikon, ratedLife: 200_000, shutterType: "電子控制縱走式機械焦平面快門"),
        "Nikon Zf": CameraModelInfo(name: "Nikon Zf", brand: .nikon, ratedLife: 200_000, shutterType: "電子控制縱走式機械焦平面快門"),
        "Nikon D6": CameraModelInfo(name: "Nikon D6", brand: .nikon, ratedLife: 400_000, shutterType: "碳纖維與克維拉複合材質機械快門"),
        "Nikon D5": CameraModelInfo(name: "Nikon D5", brand: .nikon, ratedLife: 400_000, shutterType: "碳纖維與克維拉複合材質機械快門"),
        "Nikon D850": CameraModelInfo(name: "Nikon D850", brand: .nikon, ratedLife: 200_000, shutterType: "電子前簾與減震機械快門"),
        "Nikon D780": CameraModelInfo(name: "Nikon D780", brand: .nikon, ratedLife: 150_000, shutterType: "電子控制縱走式機械快門"),
        "Nikon D750": CameraModelInfo(name: "Nikon D750", brand: .nikon, ratedLife: 150_000, shutterType: "電子控制縱走式機械快門"),
        "Nikon D500": CameraModelInfo(name: "Nikon D500", brand: .nikon, ratedLife: 200_000, shutterType: "高耐用度專業機械快門"),
        "Nikon D7500": CameraModelInfo(name: "Nikon D7500", brand: .nikon, ratedLife: 150_000, shutterType: "電子控制縱走式機械快門"),
        
        // --- Sony Alpha 系列 (ARW / JPG MakerNotes) ---
        "ILCE-1": CameraModelInfo(name: "Sony Alpha 1", brand: .sony, ratedLife: 500_000, shutterType: "雙驅動碳纖維機械快門 (支援電子閃燈同步)"),
        "ILCE-9M3": CameraModelInfo(name: "Sony Alpha 9 III", brand: .sony, ratedLife: 500_000, shutterType: "全域快門 (Global Shutter, 無機械磨損)"),
        "ILCE-9M2": CameraModelInfo(name: "Sony Alpha 9 II", brand: .sony, ratedLife: 500_000, shutterType: "低震動低噪機械快門"),
        "ILCE-7RM5": CameraModelInfo(name: "Sony Alpha 7R V", brand: .sony, ratedLife: 500_000, shutterType: "低振動低噪音電磁驅動機械快門"),
        "ILCE-7RM4": CameraModelInfo(name: "Sony Alpha 7R IV", brand: .sony, ratedLife: 500_000, shutterType: "低振動電磁驅動機械快門"),
        "ILCE-7M4": CameraModelInfo(name: "Sony Alpha 7 IV", brand: .sony, ratedLife: 200_000, shutterType: "電子控制縱走式焦平面快門"),
        "ILCE-7M3": CameraModelInfo(name: "Sony Alpha 7 III", brand: .sony, ratedLife: 200_000, shutterType: "電子控制縱走式焦平面快門"),
        "ILCE-7SM3": CameraModelInfo(name: "Sony Alpha 7S III", brand: .sony, ratedLife: 200_000, shutterType: "電子控制縱走式焦平面快門"),
        "ILCE-7CR": CameraModelInfo(name: "Sony Alpha 7CR", brand: .sony, ratedLife: 200_000, shutterType: "電子前簾與機械快門"),
        "ILCE-7C": CameraModelInfo(name: "Sony Alpha 7C", brand: .sony, ratedLife: 200_000, shutterType: "電子前簾與輕量機械快門"),
        "ILME-FX3": CameraModelInfo(name: "Sony FX3", brand: .sony, ratedLife: 200_000, shutterType: "電子控制縱走式焦平面快門"),
        "ILCE-6700": CameraModelInfo(name: "Sony Alpha 6700", brand: .sony, ratedLife: 200_000, shutterType: "電子控制縱走式焦平面快門"),
        
        // --- Fujifilm X / GFX 系列 (RAF EXIF) ---
        "GFX 100 II": CameraModelInfo(name: "Fujifilm GFX 100 II", brand: .fujifilm, ratedLife: 150_000, shutterType: "中片幅減震雙簾機械快門"),
        "GFX 100S": CameraModelInfo(name: "Fujifilm GFX 100S", brand: .fujifilm, ratedLife: 150_000, shutterType: "中片幅減震雙簾機械快門"),
        "X-T5": CameraModelInfo(name: "Fujifilm X-T5", brand: .fujifilm, ratedLife: 150_000, shutterType: "高速超薄磁石機械快門"),
        "X-T4": CameraModelInfo(name: "Fujifilm X-T4", brand: .fujifilm, ratedLife: 300_000, shutterType: "高耐用度減震磁石機械快門"),
        "X-H2S": CameraModelInfo(name: "Fujifilm X-H2S", brand: .fujifilm, ratedLife: 500_000, shutterType: "旗艦超高耐久機械快門"),
        "X-H2": CameraModelInfo(name: "Fujifilm X-H2", brand: .fujifilm, ratedLife: 500_000, shutterType: "旗艦超高耐久機械快門"),
        "X-Pro3": CameraModelInfo(name: "Fujifilm X-Pro3", brand: .fujifilm, ratedLife: 150_000, shutterType: "電子控制縱走式焦平面快門"),
        
        // --- Pentax / Ricoh 系列 ---
        "PENTAX K-1 Mark II": CameraModelInfo(name: "Pentax K-1 Mark II", brand: .generic, ratedLife: 300_000, shutterType: "全片幅專業高速防滴防塵機械快門"),
        "PENTAX K-3 Mark III": CameraModelInfo(name: "Pentax K-3 Mark III", brand: .generic, ratedLife: 300_000, shutterType: "高速輕量高耐用機械快門"),
        "RICOH GR III": CameraModelInfo(name: "Ricoh GR III", brand: .generic, ratedLife: 100_000, shutterType: "鏡間葉片快門 (Leaf Shutter)")
    ]
    
    public static var allModels: [CameraModelInfo] {
        Array(knownModels.values).sorted { $0.name < $1.name }
    }
    
    public static func lookup(name: String) -> CameraModelInfo {
        for (key, info) in knownModels {
            if name.localizedCaseInsensitiveContains(key) {
                return info
            }
        }
        let detectedBrand = CameraBrand.detect(from: name)
        return CameraModelInfo(
            name: name,
            brand: detectedBrand,
            ratedLife: 150_000,
            shutterType: "標準電子控制焦平面快門",
            shutterAddr: 0x1001,
            mirrorAddr: 0x100B,
            totalAddr: 0x1015
        )
    }
}
