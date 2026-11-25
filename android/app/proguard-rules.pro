# flutter_local_notifications serialises scheduled notifications with Gson
# (reflection), so R8 must not rename or strip these.
-keep class com.dexterous.** { *; }
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-dontwarn com.google.android.play.core.**
