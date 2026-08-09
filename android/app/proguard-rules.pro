# ML Kit text recognition (google_mlkit_text_recognition) bundluje volitelné
# rozpoznávače pro čínštinu, hindštinu, japonštinu a korejštinu, jejichž
# knihovny do appky nejsou zahrnuty (aplikace používá jen výchozí/latinský
# rozpoznávač pro čtení čísel vozů). R8 na tyto chybějící třídy jinak
# narazí a build v release režimu s minifikací selže.
# https://github.com/flutter-ml/google_ml_kit_flutter/issues (known R8 issue)
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
