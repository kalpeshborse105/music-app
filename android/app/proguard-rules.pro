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

# Google Mobile Ads SDK
-keep public class com.google.android.gms.ads.** {
   public *;
}
-keep public class com.google.ads.** {
   public *;
}
-dontwarn com.google.android.gms.ads.**

# WorkManager is pulled in transitively by Google Mobile Ads.
# AGP 9 / R8 full mode strips reflective constructors and WorkDatabase_Impl,
# which crashes release startups with:
#   Failed to create an instance of androidx.work.impl.WorkDatabase
-keep class androidx.work.** { <init>(...); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.InputMerger {
    public <init>();
}
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.paging.**
