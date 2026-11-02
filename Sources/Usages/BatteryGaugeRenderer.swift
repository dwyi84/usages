import AppKit
import Foundation

public final class BatteryGaugeRenderer {
    
    /// 테두리 없는 미니멀 세로 막대 칸(Segmented Vertical Bars) 렌더링
    /// - openCodeRemainingPercent: 0 ~ 100
    /// - googleRemainingPercent: 0 ~ 100
    /// - daysUntilReset: 가장 가까운 갱신일까지 남은 일수
    public static func renderUnifiedVerticalBars(
        openCodeRemainingPercent: Double,
        openCodeStatus: GaugeStatus,
        googleRemainingPercent: Double,
        googleStatus: GaugeStatus,
        daysUntilReset: Int
    ) -> NSImage {
        
        let canvasHeight: CGFloat = 22.0
        
        // 4개의 세로 칸(Segments)
        let segmentCount = 4
        let segmentWidth: CGFloat = 4.0
        let segmentHeight: CGFloat = 2.8
        let segmentGap: CGFloat = 1.0
        let barSpacing: CGFloat = 2.5
        
        let totalBarHeight = (CGFloat(segmentCount) * segmentHeight) + (CGFloat(segmentCount - 1) * segmentGap) // 14.2pt
        let totalWidth = (segmentWidth * 2.0) + barSpacing // 10.5pt
        let imageWidth = ceil(totalWidth) + 3.0
        let imageSize = NSSize(width: imageWidth, height: canvasHeight)
        
        // Retina 해상도에 최적화된 dynamic drawingHandler 사용 (선명한 레티나 렌더링)
        let image = NSImage(size: imageSize, flipped: false) { _ in
            let startX: CGFloat = 1.5
            let startY: CGFloat = (canvasHeight - totalBarHeight) / 2.0
            
            // 1. 왼쪽 세로 막대 (OpenCode Go)
            drawSegmentedBar(
                originX: startX,
                originY: startY,
                width: segmentWidth,
                height: segmentHeight,
                gap: segmentGap,
                count: segmentCount,
                percent: openCodeRemainingPercent
            )
            
            // 2. 오른쪽 세로 막대 (Google AI Pro)
            drawSegmentedBar(
                originX: startX + segmentWidth + barSpacing,
                originY: startY,
                width: segmentWidth,
                height: segmentHeight,
                gap: segmentGap,
                count: segmentCount,
                percent: googleRemainingPercent
            )
            
            // 3. 갱신일 임박 알림 (3일 이내 초임박 시에만 하단에 미세 도트)
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
        percent: Double
    ) {
        // 채울 칸 개수 계산 (0 ~ count)
        let activeSegments: Int
        if percent <= 0 {
            activeSegments = 0
        } else {
            // 각 칸은 25%씩 담당 (1칸: 1~25%, 2칸: 26~50%, 3칸: 51~75%, 4칸: 76~100%)
            activeSegments = max(1, min(count, Int(ceil((percent / 100.0) * Double(count)))))
        }
        
        // 잔여량 기준 색상
        let activeColor: NSColor
        if percent <= 15.0 {
            activeColor = NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)
        } else if percent <= 35.0 {
            activeColor = NSColor(red: 1.0, green: 0.62, blue: 0.05, alpha: 1.0)
        } else {
            activeColor = NSColor(red: 0.18, green: 0.82, blue: 0.35, alpha: 1.0)
        }
        
        let inactiveColor = NSColor.labelColor.withAlphaComponent(0.18)
        
        // 아래에서 위로 칸을 그림 (i = 0 이 가장 아래 칸)
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
