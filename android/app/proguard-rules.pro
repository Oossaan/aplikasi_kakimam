# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class * extends io.flutter.app.FlutterApplication { *; }

# App models and controllers (prevent obfuscation)
-keep class com.example.aplikasi_kak_imam.models.** { *; }
-keep class com.example.aplikasi_kak_imam.controllers.** { *; }
-keep class com.example.aplikasi_kak_imam.services.** { *; }

# Parcelable
-keep class * implements android.os.Parcelable {  *; }
-keep class * implements java.io.Serializable { *; }

# Plugins
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.gms.**
-keep class sqflite.** { *; }
-keep class syncfusion_flutter_pdf.** { *; }

