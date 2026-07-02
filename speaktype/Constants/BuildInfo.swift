import Foundation

/// Build timestamp shown in the debug version label. Derived at runtime from the
/// app binary's build date so it always reflects the actual build — the old
/// hardcoded constant never updated because nothing regenerated it.
let buildTimestamp: String = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "MMM d HH:mm:ss"

    let path = Bundle.main.executableURL?.path ?? Bundle.main.bundlePath
    if let date = try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]
        as? Date
    {
        return formatter.string(from: date)
    }
    return "unknown"
}()
