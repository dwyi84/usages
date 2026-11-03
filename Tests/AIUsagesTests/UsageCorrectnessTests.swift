import Foundation
import Testing
import AppKit
import SwiftUI
@testable import AIUsages

@Suite("Usage correctness")
struct UsageCorrectnessTests {
    
    // MARK: - ISO-8601 parsing
    
    @Test("Parses OpenCode fractional-second timestamps")
    func parsesFractionalSecondTimestamps() {
        // OpenCode Go returns timestamps like this. The default
        // ISO8601DateFormatter rejects them, which silently produced
        // hardcoded reset fallbacks before.
        let date = ISO8601Parser.date(from: "2026-11-09T00:00:00.000Z")
        #expect(date != nil)
        #expect(abs((date?.timeIntervalSince1970 ?? 0) - 1_794_182_400) < 0.001)
    }
    
    @Test("Parses timestamps without fractional seconds")
    func parsesPlainTimestamps() {
        #expect(ISO8601Parser.date(from: "2026-11-07T04:57:11Z") != nil)
        #expect(ISO8601Parser.date(from: "2026-11-07T04:57:11+00:00") != nil)
    }
    
    @Test("Parses microsecond and nanosecond precision")
    func parsesHighPrecisionTimestamps() {
        #expect(ISO8601Parser.date(from: "2026-11-03T17:57:37.123456Z") != nil)
        #expect(ISO8601Parser.date(from: "2026-11-03T17:57:37.123456789Z") != nil)
    }
    
    @Test("Rejects empty or invalid timestamps")
    func rejectsInvalidTimestamps() {
        #expect(ISO8601Parser.date(from: nil) == nil)
        #expect(ISO8601Parser.date(from: "") == nil)
        #expect(ISO8601Parser.date(from: "not-a-date") == nil)
    }
    
    // MARK: - Google billing date
    
    private func kstCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    
    @Test("Clamps billing day 31 to the last day of November")
    func clampsToShorterMonth() {
        let calendar = kstCalendar()
        let now = makeDate(2026, 11, 3, calendar: calendar)
        let result = GoogleAIProvider.calculateNextBilling(dayOfMonth: 31, now: now, calendar: calendar)
        #expect(result.daysRemaining == 26) // Nov 30, not Dec 1
    }
    
    @Test("Clamps billing day 31 to February 28")
    func clampsFebruary() {
        let calendar = kstCalendar()
        let now = makeDate(2026, 2, 10, calendar: calendar)
        let result = GoogleAIProvider.calculateNextBilling(dayOfMonth: 31, now: now, calendar: calendar)
        #expect(result.daysRemaining == 17)
    }
    
    @Test("Rolls a passed billing day into the next year")
    func rollsIntoNextYear() {
        let calendar = kstCalendar()
        let now = makeDate(2026, 12, 20, calendar: calendar)
        let result = GoogleAIProvider.calculateNextBilling(dayOfMonth: 5, now: now, calendar: calendar)
        #expect(result.daysRemaining == 15) // Jan 5 of the next year
    }
    
    @Test("Billing day today shows zero days")
    func billingDayToday() {
        let calendar = kstCalendar()
        let now = makeDate(2026, 11, 3, 18, calendar: calendar)
        let result = GoogleAIProvider.calculateNextBilling(dayOfMonth: 3, now: now, calendar: calendar)
        #expect(result.daysRemaining == 0)
    }
    
    @Test("Unset billing day returns no date")
    func unsetBillingDay() {
        let result = GoogleAIProvider.calculateNextBilling(dayOfMonth: 0)
        #expect(result.dateString == "")
        #expect(result.daysRemaining == 0)
    }
    
    // MARK: - Google overall quota
    
    @Test("Overall quota ignores groups missing from the API")
    func overallIgnoresMissingGroups() {
        var limits = GoogleAIGroupLimits()
        limits.geminiWeeklyRemainingPercent = 79.33
        limits.claudeWeeklyRemainingPercent = 100
        // Argon is absent for this account; it must not force overall to 0.
        #expect(abs(limits.overallRemainingPercent - 79.33) < 0.001)
    }
    
    @Test("Overall quota falls back to five-hour windows")
    func overallFallsBackToFiveHour() {
        var limits = GoogleAIGroupLimits()
        limits.geminiFiveHourRemainingPercent = 42
        limits.claudeFiveHourRemainingPercent = 73
        #expect(abs(limits.overallRemainingPercent - 42) < 0.001)
    }
    
    @Test("Overall quota is zero only when nothing is known")
    func overallZeroWhenUnknown() {
        #expect(GoogleAIGroupLimits().overallRemainingPercent == 0)
    }
    
    // MARK: - Brand marks
    
    @Test("Embedded brand SVGs render as images")
    func brandMarksRender() {
        let brands: [BrandIcon] = [
            .openCode, .googleAI, .openRouter, .codex, .claude,
            .cursor, .copilot, .perplexity, .deepseek
        ]
        for brand in brands {
            guard let svg = brand.svg else {
                Issue.record("Missing SVG for \(brand.rawValue)")
                continue
            }
            let data = Data(svg.utf8)
            #expect(NSImage(data: data) != nil, "Could not render \(brand.rawValue)")
        }
    }
    
    @Test("Brand icon views render with their configured colors")
    @MainActor
    func brandIconViewsRender() {
        let view = HStack(spacing: 16) {
            BrandIconView(.googleAI, size: 32)
            BrandIconView(.codex, size: 32)
            BrandIconView(.claude, size: 32)
            BrandIconView(.openCode, size: 32)
        }
        .padding(12)
        .background(Color.white)
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            Issue.record("ImageRenderer returned nil")
            return
        }
        #expect(image.size.width > 0 && image.size.height > 0)
    }
}
