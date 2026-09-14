/// Analytics and remote configuration abstractions.
///
/// Deliberately has **no** Firebase dependency: a Firebase-backed
/// implementation needs `google-services.json` / `GoogleService-Info.plist`
/// per app, so it lives in the app (see `apps/sudoku/lib/app/bootstrap.dart`
/// for where to plug it in). Until then the debug implementations keep
/// the app fully functional.
library;

export 'src/analytics_events.dart';
export 'src/analytics_service.dart';
export 'src/remote_config_service.dart';
