##---------------Begin: proguard configuration for Gson ----------
# Gson uses generic type information stored in a class file when working with fields.
# Proguard removes such information by default, so configure it to keep all of it.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses

# Gson specific classes
-dontwarn sun.misc.**

# Prevent ProGuard from stripping interface information from TypeAdapter, TypeAdapterFactory,
# JsonSerializer, JsonDeserializer instances
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members null
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep plugin-specific classes
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.hellobp.flutter_timezone.** { *; }
##---------------End: proguard configuration for Gson ----------
