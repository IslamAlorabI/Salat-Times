
import Foundation

/// A hash that is identical across process launches.
///
/// `Swift.Hasher` is seeded randomly per process, which is correct for in-memory
/// dictionaries and wrong for anything persisted or compared across launches —
/// notification identifiers, cache keys, change detection. Reach for this instead.
nonisolated enum StableHash {
    /// FNV-1a, 64-bit. Not cryptographic; the only requirement is that equal input
    /// gives equal output, today and next week.
    static func digest(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 36)
    }
}
