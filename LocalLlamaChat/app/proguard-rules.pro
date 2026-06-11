# Keep JS bridge methods
-keepclassmembers class com.locallm.chat.MainActivity$Bridge {
    public *;
}
-keep class com.locallm.chat.** { *; }
