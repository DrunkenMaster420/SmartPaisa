# Minimal ProGuard rules for SMS functionality

# Don't obfuscate anything
-dontobfuscate

# Keep all Flutter plugins
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# Keep SMS functionality
-keep public class * extends android.content.BroadcastReceiver {
    public <init>(...);
    public void onReceive(...);
}
-dontwarn android.content.BroadcastReceiver

# Keep SMS-related Android classes
-keep class android.provider.Telephony** { *; }

# Keep app classes
-keep class com.example.smartpaisaa.** { *; }

# Suppress common warnings
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
