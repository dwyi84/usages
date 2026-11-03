import Foundation

/// ISO-8601 parsing helpers.
///
/// Provider APIs are inconsistent about fractional seconds:
///   - OpenCode Go returns `2026-11-03T17:57:37.000Z`
///   - Google Cloud Code currently returns `2026-11-07T04:57:11Z`
///
/// `ISO8601DateFormatter` with the default options rejects fractional seconds,
/// which previously made every OpenCode reset countdown fall back to hardcoded
/// values. Always parse through this helper instead of constructing a formatter
/// at the call site.
public enum ISO8601Parser {
    public static func date(from string: String?) -> Date? {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}
