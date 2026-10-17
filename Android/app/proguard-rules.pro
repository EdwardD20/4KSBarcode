# --- Core ZXing types used by barcode writers ---
-keep class com.google.zxing.BarcodeFormat { *; }
-keep class com.google.zxing.Writer { *; }
-keep class com.google.zxing.WriterException { *; }

# --- Code128 barcode writer ---
-keep class com.google.zxing.oned.Code128Writer { *; }

# --- Matrix classes used to render the barcode ---
-keep class com.google.zxing.common.BitMatrix { *; }

# --- MultiFormatWriter if you are using it ---
-keep class com.google.zxing.MultiFormatWriter { *; }

# Silence warnings about unused ZXing components
-dontwarn com.google.zxing.**