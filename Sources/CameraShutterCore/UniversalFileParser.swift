import Foundation

public class UniversalFileParser {
    public static let supportedExtensions: Set<String> = [
        "cr3", "cr2", "nef", "arw", "raf", "dng", "jpg", "jpeg"
    ]
    
    public static func isSupported(fileExtension: String) -> Bool {
        supportedExtensions.contains(fileExtension.lowercased())
    }
    
    public static func parse(fileURL: URL) async -> ShutterReport? {
        let ext = fileURL.pathExtension.lowercased()
        guard isSupported(fileExtension: ext) else { return nil }
        
        // 1. Try system ExifTool if available
        if let report = tryExifTool(fileURL: fileURL) {
            return report
        }
        
        // 2. Binary fallback inspection
        guard let _ = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            return nil
        }
        
        return nil
    }
    
    private static func extractModelString(from data: Data) -> String? {
        let commonModels = [
            "EOS R5", "EOS R6", "EOS R8", "EOS R3", "EOS 90D",
            "Nikon Z9", "Nikon Z8", "Nikon Z6", "Nikon D850",
            "ILCE-7M4", "ILCE-7RM5", "ILCE-1"
        ]
        for m in commonModels {
            if let mData = m.data(using: .utf8), data.range(of: mData) != nil {
                return m
            }
        }
        return nil
    }
    
    private static func tryExifTool(fileURL: URL) -> ShutterReport? {
        let tool = Process()
        let outPipe = Pipe()
        tool.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        tool.arguments = ["exiftool", "-ShutterCount", "-ImageCount", "-Make", "-Model", "-SerialNumber", "-j", fileURL.path]
        tool.standardOutput = outPipe
        
        do {
            try tool.run()
            tool.waitUntilExit()
        } catch {
            return nil
        }
        
        guard tool.terminationStatus == 0 else { return nil }
        
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: outData) as? [[String: Any]],
              let first = json.first else {
            return nil
        }
        
        let rawCount = first["ShutterCount"] ?? first["ImageCount"]
        guard let countNumber = (rawCount as? Int) ?? (rawCount as? String).flatMap(Int.init) else {
            return nil
        }
        
        let make = (first["Make"] as? String) ?? ""
        let model = (first["Model"] as? String) ?? "Unknown Camera"
        let serial = (first["SerialNumber"] as? String) ?? "N/A"
        let brand = CameraBrand.detect(from: model, manufacturer: make)
        let modelInfo = CanonModelDatabase.lookup(name: model)
        
        return ShutterReport(
            cameraName: model,
            brand: brand,
            serialNumber: serial,
            shutterCount: UInt32(countNumber),
            mirrorCount: nil,
            totalActuations: UInt32(countNumber),
            ratedLife: modelInfo.ratedLife,
            readingMethod: .exifFile,
            timestamp: Date()
        )
    }
}
