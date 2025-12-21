// Conditional export: choose the correct implementation for web vs non-web.
export 'geocode_service_io.dart'
    if (dart.library.html) 'geocode_service_web.dart';
