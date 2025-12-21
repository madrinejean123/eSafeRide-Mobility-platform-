// Non-web (mobile/desktop) implementation for googleMapsApiKey.
// Reads a compile-time environment variable (kept as-is for CI / build-time
// injection). Leave default empty to avoid accidental leaking of keys.

const String googleMapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: '',
);
