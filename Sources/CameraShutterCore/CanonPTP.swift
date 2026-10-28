import Foundation

public enum PTPOpcode: UInt16 {
    case getDeviceInfo = 0x1001
    case openSession = 0x1002
    case closeSession = 0x1003
    case getDevicePropValue = 0x1015
    case setDevicePropValue = 0x1016
    
    // Canon Proprietary Factory/Vendor Opcodes
    case canonFactorySend = 0x9052
    case canonFactoryRecv = 0x9053
}

public enum PTPResponseCode: UInt16 {
    case ok = 0x2001
    case generalError = 0x2002
    case sessionNotOpen = 0x2003
    case invalidTransactionID = 0x2004
    case operationNotSupported = 0x2005
    case parameterNotSupported = 0x2006
    case devicePropNotSupported = 0x200A
    case deviceBusy = 0x2019
}

public struct PTPPacket {
    public static func buildCommand(opCode: PTPOpcode, txId: UInt32, params: [UInt32] = []) -> Data {
        let length = UInt32(12 + params.count * 4).littleEndian
        let type = UInt16(1).littleEndian // 1 = Command Block
        let code = opCode.rawValue.littleEndian
        let transaction = txId.littleEndian
        
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: length) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: type) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: code) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: transaction) { Array($0) })
        
        for param in params {
            let p = param.littleEndian
            data.append(contentsOf: withUnsafeBytes(of: p) { Array($0) })
        }
        return data
    }
}

public struct CanonFactoryPayload {
    public struct Argument {
        public var tag: UInt32 = 2 // 2 = Integer Tag
        public var value: UInt32
        
        public init(tag: UInt32 = 2, value: UInt32) {
            self.tag = tag
            self.value = value
        }
    }
    
    // Refuse dangerous write commands to protect camera hardware
    private static let dangerousCommands: Set<String> = [
        "MonWrite", "FA_SetProperty", "FA_SetCalendar", "MonCall", "FA_FactoryReset"
    ]
    
    public static func buildCommand(name: String, args: [Argument] = []) throws -> Data {
        guard !dangerousCommands.contains(name) else {
            throw NSError(domain: "CanonPTP", code: -100, userInfo: [
                NSLocalizedDescriptionKey: "Security check failed: Refusing to send mutating command '\(name)' to camera MPU."
            ])
        }
        
        var data = Data()
        
        // 1. Command Name ASCII + Null Terminator
        data.append(contentsOf: name.utf8)
        data.append(0)
        
        // 2. Argument count (argc) as UInt32 little-endian
        let argc = UInt32(args.count).littleEndian
        data.append(contentsOf: withUnsafeBytes(of: argc) { Array($0) })
        
        // 3. 20-byte record per argument
        for arg in args {
            let tag = arg.tag.littleEndian
            let val = arg.value.littleEndian
            data.append(contentsOf: withUnsafeBytes(of: tag) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: val) { Array($0) })
            data.append(contentsOf: [UInt8](repeating: 0, count: 12))
        }
        
        // 4. Trailer padding: 24 bytes of 0 if argc == 0, else 4 bytes of 0
        let trailerCount = args.isEmpty ? 24 : 4
        data.append(contentsOf: [UInt8](repeating: 0, count: trailerCount))
        
        return data
    }
    
    public static func decodeCounter(from reply: [UInt8]) -> UInt32? {
        guard reply.count >= 3 else { return nil }
        let high = UInt32(reply[1])
        var low: UInt32 = 0
        for b in reply.dropFirst(2) {
            if b != 0 {
                low = UInt32(b)
            }
        }
        return (high << 8) | low
    }
}
