import AppKit
import Foundation

/// Where the floating recorder pill sits on screen.
enum PillPosition: String, Codable, CaseIterable, Identifiable {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight

    var id: String { rawValue }

    /// UserDefaults key backing the user's chosen position.
    static let defaultsKey = "recorderPillPosition"

    /// The position used when the key is missing or invalid.
    static let defaultPosition: PillPosition = .bottomCenter

    var displayName: String {
        switch self {
        case .topLeft:      return "Top Left"
        case .topCenter:    return "Top Center"
        case .topRight:     return "Top Right"
        case .centerLeft:   return "Middle Left"
        case .center:       return "Center"
        case .centerRight:  return "Middle Right"
        case .bottomLeft:   return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight:  return "Bottom Right"
        }
    }

    /// Pure geometry: where the panel's top-left should land for a given
    /// position, panel size, and screen-visible frame. Inset from all four
    /// screen edges by `edgeInset` so the pill never sits flush with the
    /// menu bar or dock.
    static func origin(
        for position: PillPosition,
        panelSize: NSSize,
        visibleFrame: NSRect,
        edgeInset: CGFloat = 8
    ) -> NSPoint {
        let midY = visibleFrame.midY - panelSize.height / 2
        let topY = visibleFrame.maxY - panelSize.height - edgeInset
        let bottomY = visibleFrame.minY + edgeInset
        let leftX = visibleFrame.minX + edgeInset
        let rightX = visibleFrame.maxX - panelSize.width - edgeInset
        let centerX = visibleFrame.midX - panelSize.width / 2

        switch position {
        case .topLeft:      return NSPoint(x: leftX,    y: topY)
        case .topCenter:    return NSPoint(x: centerX,  y: topY)
        case .topRight:     return NSPoint(x: rightX,   y: topY)
        case .centerLeft:   return NSPoint(x: leftX,    y: midY)
        case .center:       return NSPoint(x: centerX,  y: midY)
        case .centerRight:  return NSPoint(x: rightX,   y: midY)
        case .bottomLeft:   return NSPoint(x: leftX,    y: bottomY)
        case .bottomCenter: return NSPoint(x: centerX,  y: bottomY)
        case .bottomRight:  return NSPoint(x: rightX,   y: bottomY)
        }
    }
}
