# ============================================================
# Ringinout ProGuard / R8 Rules
# ============================================================

# ?�?� Flutter ?�?�
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ?�?� App Kotlin classes (MethodChannel, BroadcastReceiver, Activity) ?�?�
-keep class com.bnt0514.ringinout.** { *; }

# ?�?� Google Play Services (Location, Maps) ?�?�
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ?�?� Firebase ?�?�
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ?�?� Hive ?�?�
-keep class io.hive.** { *; }
-dontwarn io.hive.**

# ?�?� Google Maps Flutter ?�?�
-keep class com.google.android.gms.maps.** { *; }

# ?�?� Naver Maps ?�?�
-keep class com.naver.maps.** { *; }
-dontwarn com.naver.maps.**

# ?�?� Gson / JSON serialization (Firebase ?�에???�용) ?�?�
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# ?�?� gRPC (Firestore ?��? ?�용) ?�?�
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**

# ?�?� SharedPreferences (Flutter plugin) ?�?�
-keep class androidx.datastore.** { *; }
-dontwarn androidx.datastore.**

# ?�?� Android 기본 ?�?�
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ?�?� Ringtone (?�람 벨소�? ?�?�
-keep class android.media.Ringtone { *; }
-keep class android.media.RingtoneManager { *; }

# ?�?� Suppress warnings ?�?�
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.**
-dontwarn kotlin.**
