import Foundation

public enum CameraBrand: String, CaseIterable, Identifiable, Codable, Sendable {
    case canon = "Canon"
    case nikon = "Nikon"
    case sony = "Sony"
    case fujifilm = "Fujifilm"
    case pentax = "Pentax"
    case panasonic = "Panasonic"
    case generic = "Universal"
    
    public var id: String { rawValue }
    
    public static func detect(from deviceName: String, manufacturer: String? = nil) -> CameraBrand {
        let combined = "\(deviceName) \(manufacturer ?? "")".lowercased()
        
        if combined.contains("canon") { return .canon }
        if combined.contains("nikon") { return .nikon }
        if combined.contains("sony") { return .sony }
        if combined.contains("fuji") { return .fujifilm }
        if combined.contains("pentax") || combined.contains("ricoh") { return .pentax }
        if combined.contains("panasonic") || combined.contains("lumix") { return .panasonic }
        
        return .generic
    }
}
