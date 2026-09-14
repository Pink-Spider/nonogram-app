import 'package:flutter/foundation.dart';

abstract class AnalyticsService {
  Future<void> logEvent(String name, [Map<String, Object> params = const {}]);
  Future<void> setUserProperty(String name, String? value);
  Future<void> logScreen(String screenName);
}

/// Prints events in debug builds; silent in release.
class DebugAnalyticsService implements AnalyticsService {
  const DebugAnalyticsService();

  @override
  Future<void> logEvent(String name, [Map<String, Object> params = const {}]) async {
    if (kDebugMode) debugPrint('[analytics] $name $params');
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    if (kDebugMode) debugPrint('[analytics] user.$name = $value');
  }

  @override
  Future<void> logScreen(String screenName) async {
    if (kDebugMode) debugPrint('[analytics] screen $screenName');
  }
}

/// Fan-out to several services (e.g. debug + Firebase).
class CompositeAnalyticsService implements AnalyticsService {
  const CompositeAnalyticsService(this.services);

  final List<AnalyticsService> services;

  @override
  Future<void> logEvent(String name, [Map<String, Object> params = const {}]) =>
      Future.wait(services.map((s) => s.logEvent(name, params)));

  @override
  Future<void> setUserProperty(String name, String? value) =>
      Future.wait(services.map((s) => s.setUserProperty(name, value)));

  @override
  Future<void> logScreen(String screenName) =>
      Future.wait(services.map((s) => s.logScreen(screenName)));
}
