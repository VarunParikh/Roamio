# Release builds shrink code with R8. The ML Kit text-recognition plugin refers
# to optional language packs (Chinese, Devanagari, Japanese, Korean) that the
# app doesn't include; Latin script only, so those classes are never loaded.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
