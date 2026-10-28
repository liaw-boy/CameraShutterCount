import Foundation

public struct CameraModelInfo: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let brand: CameraBrand
    public let ratedLife: UInt32
    public let mpuShutterAddress: UInt32?
    public let mpuMirrorAddress: UInt32?
    public let mpuTotalAddress: UInt32?
    
    public init(name: String, brand: CameraBrand = .canon, ratedLife: UInt32, shutterAddr: UInt32? = nil, mirrorAddr: UInt32? = nil, totalAddr: UInt32? = nil) {
        self.name = name
        self.brand = brand
        self.ratedLife = ratedLife
        self.mpuShutterAddress = shutterAddr
        self.mpuMirrorAddress = mirrorAddr
        self.mpuTotalAddress = totalAddr
    }
}

public struct ShutterReport: Sendable {
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
        timestamp: Date
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
    
    public enum ReadingMethod: String, Sendable {
        case ptpLegacy = "PTP Standard Property"
        case ptpMpuMonitor = "Canon MPU Vendor Channel (0x9052)"
        case cr3MakerNotes = "RAW / EXIF MakerNotes"
        case exifFile = "EXIF Metadata"
    }
}

public enum CanonModelDatabase {
    public static let knownModels: [String: CameraModelInfo] = [
        // Canon Modern DSLRs
        "EOS 5D Mark IV": CameraModelInfo(name: "EOS 5D Mark IV", brand: .canon, ratedLife: 150_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 5DS": CameraModelInfo(name: "EOS 5DS", brand: .canon, ratedLife: 150_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 5DS R": CameraModelInfo(name: "EOS 5DS R", brand: .canon, ratedLife: 150_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 1D X Mark II": CameraModelInfo(name: "EOS 1D X Mark II", brand: .canon, ratedLife: 400_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 1D X Mark III": CameraModelInfo(name: "EOS 1D X Mark III", brand: .canon, ratedLife: 500_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 80D": CameraModelInfo(name: "EOS 80D", brand: .canon, ratedLife: 100_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 90D": CameraModelInfo(name: "EOS 90D", brand: .canon, ratedLife: 120_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 6D Mark II": CameraModelInfo(name: "EOS 6D Mark II", brand: .canon, ratedLife: 100_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        "EOS 7D Mark II": CameraModelInfo(name: "EOS 7D Mark II", brand: .canon, ratedLife: 200_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015),
        
        // Canon Classic DSLRs
        "EOS 5D Mark III": CameraModelInfo(name: "EOS 5D Mark III", brand: .canon, ratedLife: 150_000),
        "EOS 5D Mark II": CameraModelInfo(name: "EOS 5D Mark II", brand: .canon, ratedLife: 150_000),
        "EOS 6D": CameraModelInfo(name: "EOS 6D", brand: .canon, ratedLife: 100_000),
        "EOS 7D": CameraModelInfo(name: "EOS 7D", brand: .canon, ratedLife: 150_000),
        "EOS 70D": CameraModelInfo(name: "EOS 70D", brand: .canon, ratedLife: 100_000),
        "EOS 60D": CameraModelInfo(name: "EOS 60D", brand: .canon, ratedLife: 100_000),
        
        // Canon EOS R Mirrorless
        "EOS R": CameraModelInfo(name: "EOS R", brand: .canon, ratedLife: 200_000),
        "EOS RP": CameraModelInfo(name: "EOS RP", brand: .canon, ratedLife: 100_000),
        "EOS R5": CameraModelInfo(name: "EOS R5", brand: .canon, ratedLife: 500_000),
        "EOS R6": CameraModelInfo(name: "EOS R6", brand: .canon, ratedLife: 300_000),
        "EOS R6 Mark II": CameraModelInfo(name: "EOS R6 Mark II", brand: .canon, ratedLife: 400_000),
        "EOS R7": CameraModelInfo(name: "EOS R7", brand: .canon, ratedLife: 200_000),
        "EOS R8": CameraModelInfo(name: "EOS R8", brand: .canon, ratedLife: 100_000),
        "EOS R3": CameraModelInfo(name: "EOS R3", brand: .canon, ratedLife: 500_000),
        
        // Nikon Models
        "Nikon Z9": CameraModelInfo(name: "Nikon Z9", brand: .nikon, ratedLife: 500_000),
        "Nikon Z8": CameraModelInfo(name: "Nikon Z8", brand: .nikon, ratedLife: 400_000),
        "Nikon Z6 II": CameraModelInfo(name: "Nikon Z6 II", brand: .nikon, ratedLife: 200_000),
        "Nikon Z7 II": CameraModelInfo(name: "Nikon Z7 II", brand: .nikon, ratedLife: 200_000),
        "Nikon D850": CameraModelInfo(name: "Nikon D850", brand: .nikon, ratedLife: 200_000),
        
        // Sony Models
        "ILCE-7M4": CameraModelInfo(name: "Sony A7 IV", brand: .sony, ratedLife: 200_000),
        "ILCE-7RM5": CameraModelInfo(name: "Sony A7R V", brand: .sony, ratedLife: 500_000),
        "ILCE-1": CameraModelInfo(name: "Sony A1", brand: .sony, ratedLife: 500_000)
    ]
    
    public static func lookup(name: String) -> CameraModelInfo {
        for (key, info) in knownModels {
            if name.localizedCaseInsensitiveContains(key) {
                return info
            }
        }
        let detectedBrand = CameraBrand.detect(from: name)
        return CameraModelInfo(name: name, brand: detectedBrand, ratedLife: 150_000, shutterAddr: 0x1001, mirrorAddr: 0x100B, totalAddr: 0x1015)
    }
}
