# Keep Kotlin & Compose runtime metadata
-keepattributes *Annotation*
-keep class com.melissasoft.aiusages.model.** { *; }

# Compile-time-only annotations referenced by Tink in androidx.security:security-crypto
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
