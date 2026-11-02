import AppKit
import Foundation

public final class BatteryGaugeRenderer {
    
    /// 배터리 바와 텍스트를 포함한 NSImage 생성
    public static func renderBatteryItem(
        label: String?,
        percent: Double,       // 0 ~ 100
        isUsedRatio: Bool = false, // false면 남은 용량(100%->0%), true면 사용량(0%->100%)
        showPercent: Bool = true,
        status: GaugeStatus = .normal
    ) -> NSImage {
        // 남은 게이지 계산 (배터리 게이지는 시각적으로 "남은 잔여량"을 보여주는 것이 직관적)
        // 사용자가 20% 썼으면 배터리는 80% 차있는 모양
        let fillRatio: Double
        if isUsedRatio {
            fillRatio = max(0.0, min(1.0, percent / 100.0))
        } else {
            fillRatio = max(0.0, min(1.0, (100.0 - percent) / 100.0))
        }
        
        let labelText = label ?? ""
        let percentText = showPercent ? "\(Int(round(percent)))%" : ""
        
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.0, weight: .semibold)
        let labelFont = NSFont.systemFont(ofSize: 9.5, weight: .bold)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let percentAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        
        let labelSize = labelText.isEmpty ? .zero : (labelText as NSString).size(withAttributes: labelAttrs)
        let percentSize = percentText.isEmpty ? .zero : (percentText as NSString).size(withAttributes: percentAttrs)
        
        let batteryWidth: CGFloat = 20.0
        let batteryHeight: CGFloat = 10.5
        let spacing: CGFloat = 3.5
        
        var totalWidth: CGFloat = 0.0
        if !labelText.isEmpty {
            totalWidth += labelSize.width + spacing
        }
        totalWidth += batteryWidth + 2.0 // battery + cap
        if !percentText.isEmpty {
            totalWidth += spacing + percentSize.width
        }
        
        let canvasHeight: CGFloat = 22.0
        let imageSize = NSSize(width: ceil(totalWidth) + 2.0, height: canvasHeight)
        
        let image = NSImage(size: imageSize)
        image.lockFocus()
        
        var currentX: CGFloat = 1.0
        
        // 1. 라벨 그리기 (예: "OC" or "G")
        if !labelText.isEmpty {
            let labelY = (canvasHeight - labelSize.height) / 2.0
            (labelText as NSString).draw(at: NSPoint(x: currentX, y: labelY), withAttributes: labelAttrs)
            currentX += labelSize.width + spacing
        }
        
        // 2. 배터리 게이지 그리기
        let batteryY = (canvasHeight - batteryHeight) / 2.0
        let bodyRect = NSRect(x: currentX, y: batteryY, width: batteryWidth, height: batteryHeight)
        
        // 배터리 외곽선
        let borderPath = NSBezierPath(roundedRect: bodyRect, xRadius: 2.5, yRadius: 2.5)
        borderPath.lineWidth = 1.0
        NSColor.labelColor.withAlphaComponent(0.65).setStroke()
        borderPath.stroke()
        
        // 배터리 양극 팁 (오른쪽 캡)
        let capWidth: CGFloat = 1.5
        let capHeight: CGFloat = 4.0
        let capX = bodyRect.maxX + 1.0
        let capY = batteryY + (batteryHeight - capHeight) / 2.0
        let capPath = NSBezierPath(roundedRect: NSRect(x: capX, y: capY, width: capWidth, height: capHeight), xRadius: 0.8, yRadius: 0.8)
        NSColor.labelColor.withAlphaComponent(0.65).setFill()
        capPath.fill()
        
        // 배터리 내부 채우기 (Fill)
        let innerPadding: CGFloat = 1.5
        let maxFillWidth = batteryWidth - (innerPadding * 2.0)
        let fillWidth = max(0.0, maxFillWidth * CGFloat(fillRatio))
        
        if fillWidth > 0.5 {
            let innerRect = NSRect(
                x: currentX + innerPadding,
                y: batteryY + innerPadding,
                width: fillWidth,
                height: batteryHeight - (innerPadding * 2.0)
            )
            let fillPath = NSBezierPath(roundedRect: innerRect, xRadius: 1.2, yRadius: 1.2)
            
            // 색상 결정
            let fillColor: NSColor
            switch status {
            case .critical:
                fillColor = NSColor.systemRed
            case .warning:
                fillColor = NSColor.systemOrange
            case .normal:
                // 잔여량이 20% 미만이면 경고색
                if fillRatio < 0.15 {
                    fillColor = NSColor.systemRed
                } else if fillRatio < 0.35 {
                    fillColor = NSColor.systemOrange
                } else {
                    fillColor = NSColor.systemGreen
                }
            case .error:
                fillColor = NSColor.systemGray
            case .unknown:
                fillColor = NSColor.secondaryLabelColor
            }
            
            fillColor.setFill()
            fillPath.fill()
        }
        
        currentX += batteryWidth + 2.0 + spacing
        
        // 3. 퍼센트 텍스트 그리기
        if !percentText.isEmpty {
            let percentY = (canvasHeight - percentSize.height) / 2.0
            (percentText as NSString).draw(at: NSPoint(x: currentX, y: percentY), withAttributes: percentAttrs)
        }
        
        image.unlockFocus()
        image.isTemplate = false // 색상이 들어가므로 template 해제
        return image
    }
    
    /// 두 서비스를 하나의 메뉴바 아이콘으로 묶어 렌더링
    public static func renderCombinedItem(
        openCodePercent: Double,
        openCodeStatus: GaugeStatus,
        googlePercent: Double,
        googleStatus: GaugeStatus,
        showPercent: Bool = true
    ) -> NSImage {
        let ocImage = renderBatteryItem(
            label: "OC",
            percent: openCodePercent,
            showPercent: showPercent,
            status: openCodeStatus
        )
        let gImage = renderBatteryItem(
            label: "G",
            percent: googlePercent,
            showPercent: showPercent,
            status: googleStatus
        )
        
        let dividerWidth: CGFloat = 8.0
        let totalWidth = ocImage.size.width + dividerWidth + gImage.size.width
        let canvasHeight: CGFloat = 22.0
        
        let combined = NSImage(size: NSSize(width: totalWidth, height: canvasHeight))
        combined.lockFocus()
        
        ocImage.draw(at: NSPoint(x: 0, y: 0), from: .zero, operation: .sourceOver, fraction: 1.0)
        
        // 구분선 (심플한 도트 또는 얇은 선)
        let dividerX = ocImage.size.width + (dividerWidth / 2.0)
        let divPath = NSBezierPath()
        divPath.move(to: NSPoint(x: dividerX, y: 5.0))
        divPath.line(to: NSPoint(x: dividerX, y: 17.0))
        divPath.lineWidth = 0.8
        NSColor.separatorColor.setStroke()
        divPath.stroke()
        
        gImage.draw(at: NSPoint(x: ocImage.size.width + dividerWidth, y: 0), from: .zero, operation: .sourceOver, fraction: 1.0)
        
        combined.unlockFocus()
        combined.isTemplate = false
        return combined
    }
}
