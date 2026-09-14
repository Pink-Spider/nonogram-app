# Google Mobile Ads and the UMP SDK reflect over their own classes.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }

# Flutter's embedding is referenced from generated code and the manifest.
-keep class io.flutter.embedding.** { *; }

# Flutter's embedding also references Play Core's deferred-component API,
# which is not on the classpath because this app does not use deferred
# components. Without this R8 fails the build on the missing classes.
-dontwarn com.google.android.play.core.**

# WorkManager + Room. google_mobile_ads pulls in androidx.work for offline
# ad pings; WorkManager looks up the Room-generated WorkDatabase_Impl by
# name, so R8 renaming it kills the app at startup with
#   "Failed to create an instance of androidx.work.impl.WorkDatabase"
# inside androidx.startup.InitializationProvider — before any Dart runs.
# This only reproduces in release builds (debug does not run R8), which is
# how it reached Play review and got the app rejected. Do not remove.
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }
-keep class androidx.room.** { *; }
-keep class androidx.sqlite.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.ListenableWorker { public <init>(...); }
-dontwarn androidx.work.**
