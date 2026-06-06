public enum ChronoCoreInfo {
    public static let version = "0.1.0"
}

/// Deterministic, process-independent string hash (FNV-1a 64-bit) for cache
/// fingerprints. Swift's Hasher is randomized per process and must not be used
/// for stable cache keys.
enum DeterministicHash {
    static func fnv1aHex(_ string: String) -> String {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x00000100000001B3
        }
        return String(hash, radix: 16)
    }
}
