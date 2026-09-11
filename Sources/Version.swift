import Foundation

/// Kept separate and pure so the comparison can be unit tested.
enum Version {
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func parts(_ s: String) -> [Int] {
        s.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}
