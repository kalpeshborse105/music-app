# Kalpkrut Beats - release (minify) ProGuard/R8 rules.

# Keep the audio_service + just_audio native bridges used via reflection/JNI.
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.kalpkrut.beats.** { *; }

# AndroidX MediaSession
-keep class androidx.media.** { *; }

# Flutter engine embedding entry points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep kotlin metadata
-keep class kotlin.Metadata { *; }
-dontwarn org.jetbrains.annotations.**
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
