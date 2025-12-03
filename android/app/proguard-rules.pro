# Evitar que R8 elimine o rompa el plugin de Google Maps
-keep class io.flutter.plugins.googlemaps.** { *; }
-dontwarn io.flutter.plugins.googlemaps.**
-keep class io.flutter.plugin.** { *; }