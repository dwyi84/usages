import AppKit
import Foundation

public final class BatteryGaugeRenderer {
    
    /// 하나로 합쳐진 트윈 세로바(Twin Vertical Bars) 배터리 게이지 렌더링
    /// - openCodeRemainingPercent: 0 ~ 100 (남은 양)
    /// - googleRemainingPercent: 0 ~ 100 (남은 양)
    /// - daysUntilReset: 가장 가까운 갱신일까지 남은 일수
    public static func renderUnifiedVerticalBars(
        openCodeRemainingPercent: Double,
        openCodeStatus: GaugeStatus,
        googleRemainingPercent: Double,
        googleStatus: GaugeStatus,
        daysUntilReset: Int
    ) -> NSImage {
        
        let canvasHeight: CGFloat = 22.0
        let frameWidth: CGFloat = 18.0
        let frameHeight: CGFloat = 15.0
        let imageSize = NSSize(width: frameWidth + 2.0, height: canvasHeight)
        
        let image = NSImage(size: imageSize)
        image.lockFocus()
        
        let frameX: CGFloat = 1.0
        let frameY: CGFloat = (canvasHeight - frameHeight) / 2.0
        let outerRect = NSRect(x: frameX, y: frameY, width: frameWidth, height: frameHeight)
        
        // 1. 외곽선 캡슐 (우측 +전극 없는 직사각형 라운드)
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 3.0, yRadius: 3.0)
        outerPath.lineWidth = 1.0
        NSColor.labelColor.withAlphaComponent(0.60).setStroke()
        outerPath.stroke()
        
        // 2. 내부 2개 세로바 영역 (왼쪽: OpenCode, 오른쪽: Google AI)
        let innerPaddingX: CGFloat = 2.5
        let innerPaddingY: CGFloat = 2.5
        let barSpacing: CGFloat = 2.0
        let innerWidth = frameWidth - (innerPaddingX * 2.0)
        let innerHeight = frameHeight - (innerPaddingY * 2.0)
        let barWidth = (innerWidth - barSpacing) / 2.0
        
        let ocFillRatio = max(0.05, min(1.0, openCodeRemainingPercent / 100.0))
        let gFillRatio = max(0.05, min(1.0, googleRemainingPercent / 100.0))
        
        // 2-1. 왼쪽 세로바 (OpenCode Go)
        let ocBarX = frameX + innerPaddingX
        let ocBarHeight = max(1.5, innerHeight * CGFloat(ocFillRatio))
        let ocBarY = frameY + innerPaddingY
        let ocBarRect = NSRect(x: ocBarX, y: ocBarY, width: barWidth, height: ocBarHeight)
        let ocPath = NSBezierPath(roundedRect: ocBarRect, xRadius: 1.2, yRadius: 1.2)
        getFillColor(remainingRatio: ocFillRatio, status: openCodeStatus).setFill()
        ocPath.fill()
        
        // 2-2. 오른쪽 세로바 (Google AI Pro)
        let gBarX = ocBarX + barWidth + barSpacing
        let gBarHeight = max(1.5, innerHeight * CGFloat(gFillRatio))
        let gBarY = frameY + innerPaddingY
        let gBarRect = NSRect(x: gBarX, y: gBarY, width: barWidth, height: gBarHeight)
        let gPath = NSBezierPath(roundedRect: gBarRect, xRadius: 1.2, yRadius: 1.2)
        getFillColor(remainingRatio: gFillRatio, status: googleStatus).setFill()
        gPath.fill()
        
        // 3. 갱신일(Reset D-day) 인디케이터 도트
        let dotDiameter: CGFloat = 2.2
        let dotX = frameX + (frameWidth - dotDiameter) / 2.0
        let dotY = outerRect.maxY - 1.2
        let dotRect = NSRect(x: dotX, y: dotY, width: dotDiameter, height: dotDiameter)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        
        if daysUntilReset <= 3 && daysUntilReset >= 0 {
            NSColor.systemYellow.setFill()
            dotPath.fill()
        } else if daysUntilReset <= 7 {
            NSColor.systemTeal.setFill()
            dotPath.fill()
        } else {
            NSColor.labelColor.withAlphaComponent(0.3).setFill()
            dotPath.fill()
        }
        
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
    
    private static func getFillColor(remainingRatio: Double, status: GaugeStatus) -> NSColor {
        if status == .critical || remainingRatio <= 0.15 {
            return NSColor.systemRed
        } else if status == .warning || remainingRatio <= 0.35 {
            return NSColor.systemOrange
        } else {
            return NSColor.systemGreen
        }
    }
}
