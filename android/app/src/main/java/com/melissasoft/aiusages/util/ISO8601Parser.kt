package com.melissasoft.aiusages.util

import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeParseException

/**
 * ISO-8601 parsing helpers.
 *
 * Provider APIs are inconsistent about fractional seconds:
 *   - OpenCode Go returns `2026-11-03T17:57:37.000Z`
 *   - Google Cloud Code returns `2026-11-07T04:57:11Z`
 */
object ISO8601Parser {
    fun parseInstant(raw: String?): Instant? {
        val trimmed = raw?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        return try {
            Instant.parse(trimmed)
        } catch (_: DateTimeParseException) {
            try {
                OffsetDateTime.parse(trimmed).toInstant()
            } catch (_: DateTimeParseException) {
                null
            }
        }
    }
}
