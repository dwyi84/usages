import AppKit
import Foundation

public final class BatteryGaugeRenderer {
    
    public struct GaugeItem {
        public let percent: Double
        public let status: GaugeStatus
        
        public init(percent: Double, status: GaugeStatus) {
            self.percent = percent
            self.status = status
        }
    }
    
    /// 활성화된 프로바이더 수에 맞춰 유연하게 렌더링하는 미니멀 세로 막대 칸
    public static func renderDynamicBars(
        items: [GaugeItem],
        daysUntilReset: Int
    ) -> NSImage {
        let canvasHeight: CGFloat = 22.0
        let segmentCount = 4
        let segmentWidth: CGFloat = 4.0
        let segmentHeight: CGFloat = 2.8
        let segmentGap: CGFloat = 1.0
        let barSpacing: CGFloat = 2.5
        
        let displayItems = items.isEmpty ? [GaugeItem(percent: 0.0, status: .unknown)] : Array(items.prefix(3))
        let barCount = displayItems.count
        
        let totalBarHeight = (CGFloat(segmentCount) * segmentHeight) + (CGFloat(segmentCount - 1) * segmentGap) // 14.2pt
        let totalWidth = (CGFloat(barCount) * segmentWidth) + (CGFloat(max(0, barCount - 1)) * barSpacing)
        let imageWidth = ceil(totalWidth) + 3.0
        let imageSize = NSSize(width: max(14.0, imageWidth), height: canvasHeight)
        
        let image = NSImage(size: imageSize, flipped: false) { _ in
            let startX: CGFloat = 1.5
            let startY: CGFloat = (canvasHeight - totalBarHeight) / 2.0
            
            for (idx, item) in displayItems.enumerated() {
                let barX = startX + CGFloat(idx) * (segmentWidth + barSpacing)
                drawSegmentedBar(
                    originX: barX,
                    originY: startY,
                    width: segmentWidth,
                    height: segmentHeight,
                    gap: segmentGap,
                    count: segmentCount,
                    percent: item.percent,
                    status: item.status
                )
            }
            
            // 갱신일 임박 알림 (3일 이내 초임박 시에만 하단 미세 도트)
            if daysUntilReset <= 3 && daysUntilReset >= 0 {
                let dotSize: CGFloat = 1.8
                let dotX = startX + (totalWidth - dotSize) / 2.0
                let dotY = max(0.5, startY - 2.8)
                let dotPath = NSBezierPath(ovalIn: NSRect(x: dotX, y: dotY, width: dotSize, height: dotSize))
                NSColor.systemOrange.setFill()
                dotPath.fill()
            }
            
            return true
        }
        
        image.isTemplate = false
        return image
    }
    
    private static func drawSegmentedBar(
        originX: CGFloat,
        originY: CGFloat,
        width: CGFloat,
        height: CGFloat,
        gap: CGFloat,
        count: Int,
        percent: Double,
        status: GaugeStatus
    ) {
        let activeSegments: Int
        if percent <= 0 {
            activeSegments = 0
        } else {
            activeSegments = max(1, min(count, Int(ceil((percent / 100.0) * Double(count)))))
        }
        
        let activeColor: NSColor
        if status == .rateLimited {
            activeColor = NSColor.systemPurple
        } else if percent <= 15.0 {
            activeColor = NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)
        } else if percent <= 35.0 {
            activeColor = NSColor(red: 1.0, green: 0.62, blue: 0.05, alpha: 1.0)
        } else {
            activeColor = NSColor(red: 0.18, green: 0.82, blue: 0.35, alpha: 1.0)
        }
        
        let inactiveColor = NSColor.labelColor.withAlphaComponent(0.18)
        
        for i in 0..<count {
            let segmentY = originY + CGFloat(i) * (height + gap)
            let rect = NSRect(x: originX, y: segmentY, width: width, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: 0.8, yRadius: 0.8)
            
            if i < activeSegments {
                activeColor.setFill()
            } else {
                inactiveColor.setFill()
            }
            path.fill()
        }
    }
}
