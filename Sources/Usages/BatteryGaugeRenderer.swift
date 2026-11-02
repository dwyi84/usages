import AppKit
import Foundation

public final class BatteryGaugeRenderer {
    
    /// 하나로 합쳐진 세로바(Twin Vertical Bars) 배터리 아이콘 렌더링
    /// - openCodeMonthlyPercent: 0 ~ 100 (사용률)
    /// - googleMonthlyPercent: 0 ~ 100 (사용률)
    /// - daysUntilReset: 가장 가까운 갱신일까지 남은 일수
    public static func renderUnifiedVerticalBars(
        openCodeMonthlyPercent: Double,
        openCodeStatus: GaugeStatus,
        googleMonthlyPercent: Double,
        googleStatus: GaugeStatus,
        daysUntilReset: Int
    ) -> NSImage {
        
        // 메뉴바 표준 높이 22pt
        let canvasHeight: CGFloat = 22.0
        let frameWidth: CGFloat = 18.0
        let frameHeight: CGFloat = 15.0
        let imageSize = NSSize(width: frameWidth + 2.0, height: canvasHeight)
        
        let image = NSImage(size: imageSize)
        image.lockFocus()
        
        let frameX: CGFloat = 1.0
        let frameY: CGFloat = (canvasHeight - frameHeight) / 2.0
        let outerRect = NSRect(x: frameX, y: frameY, width: frameWidth, height: frameHeight)
        
        // 1. 외곽선 캡슐 (우측 +전극 없는 깔끔한 둥근 사각형)
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 3.0, yRadius: 3.0)
        outerPath.lineWidth = 1.0
        NSColor.labelColor.withAlphaComponent(0.60).setStroke()
        outerPath.stroke()
        
        // 2. 내부 2개의 세로바 영역 계산
        let innerPaddingX: CGFloat = 2.5
        let innerPaddingY: CGFloat = 2.5
        let barSpacing: CGFloat = 2.0
        let innerWidth = frameWidth - (innerPaddingX * 2.0)
        let innerHeight = frameHeight - (innerPaddingY * 2.0)
        let barWidth = (innerWidth - barSpacing) / 2.0 // 약 4.5pt
        
        // 게이지는 배터리처럼 "잔여량(Remaining %)"이 높을수록 위까지 차있도록 렌더링
        let ocFillRatio = max(0.05, min(1.0, (100.0 - openCodeMonthlyPercent) / 100.0))
        let gFillRatio = max(0.05, min(1.0, (100.0 - googleMonthlyPercent) / 100.0))
        
        // 2-1. 왼쪽 세로바: OpenCode Go 월간 게이지 (아래에서 위로)
        let ocBarX = frameX + innerPaddingX
        let ocBarHeight = max(1.5, innerHeight * CGFloat(ocFillRatio))
        let ocBarY = frameY + innerPaddingY // 바닥 기준
        
        let ocBarRect = NSRect(x: ocBarX, y: ocBarY, width: barWidth, height: ocBarHeight)
        let ocPath = NSBezierPath(roundedRect: ocBarRect, xRadius: 1.2, yRadius: 1.2)
        getFillColor(ratio: ocFillRatio, status: openCodeStatus).setFill()
        ocPath.fill()
        
        // 2-2. 오른쪽 세로바: Google AI Pro 월간 게이지 (아래에서 위로)
        let gBarX = ocBarX + barWidth + barSpacing
        let gBarHeight = max(1.5, innerHeight * CGFloat(gFillRatio))
        let gBarY = frameY + innerPaddingY
        
        let gBarRect = NSRect(x: gBarX, y: gBarY, width: barWidth, height: gBarHeight)
        let gPath = NSBezierPath(roundedRect: gBarRect, xRadius: 1.2, yRadius: 1.2)
        getFillColor(ratio: gFillRatio, status: googleStatus).setFill()
        gPath.fill()
        
        // 3. 갱신일(Reset Date) 근접 여부 인디케이터
        // - 갱신일이 3일 이내로 임박했을 때: 상단에 시안/옐로우 펄스 도트 표시
        // - 갱신일이 멀었을 때(> 7일): 상단 림에 은은한 차분한 도트 또는 얇은 라인
        let dotDiameter: CGFloat = 2.2
        let dotX = frameX + (frameWidth - dotDiameter) / 2.0
        let dotY = outerRect.maxY - 1.2 // 프레임 상단 엣지 중앙
        
        let dotRect = NSRect(x: dotX, y: dotY, width: dotDiameter, height: dotDiameter)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        
        if daysUntilReset <= 3 && daysUntilReset >= 0 {
            // 갱신일 임박: 눈에 띄는 밝은 주황/노랑 도트 (리셋 다가옴!)
            NSColor.systemYellow.setFill()
            dotPath.fill()
        } else if daysUntilReset <= 7 {
            // 1주일 이내: 시안/하늘색 도트
            NSColor.systemTeal.setFill()
            dotPath.fill()
        } else {
            // 여유 있음: 조용한 반투명 도트
            NSColor.labelColor.withAlphaComponent(0.3).setFill()
            dotPath.fill()
        }
        
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
    
    private static func getFillColor(ratio: Double, status: GaugeStatus) -> NSColor {
        if status == .critical || ratio < 0.15 {
            return NSColor.systemRed
        } else if status == .warning || ratio < 0.35 {
            return NSColor.systemOrange
        } else {
            return NSColor.systemGreen
        }
    }
}
