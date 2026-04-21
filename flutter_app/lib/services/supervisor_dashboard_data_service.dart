import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class SupervisorDashboardDataService {
  static const Duration _ttl = Duration(seconds: 45);

  static final Map<String, _CacheEntry<List<Map<String, dynamic>>>> _cache =
      <String, _CacheEntry<List<Map<String, dynamic>>>>{};
  static final Map<String, Future<List<Map<String, dynamic>>>> _inFlight =
      <String, Future<List<Map<String, dynamic>>>>{};

  static Future<List<Map<String, dynamic>>> fetchTasksForProject(
    int projectId,
  ) {
    return _fetchCollection(
      key: 'tasks:$projectId',
      endpoint: 'subtasks/?project_id=$projectId',
    );
  }

  static Future<List<Map<String, dynamic>>> fetchWorkersForProject(
    int projectId,
  ) async {
    final key = 'workers:$projectId';
    final now = DateTime.now();
    final cached = _cache[key];
    if (cached != null && now.difference(cached.cachedAt) <= _ttl) {
      return cached.value;
    }

    final existing = _inFlight[key];
    if (existing != null) {
      return existing;
    }

    final future = _requestWorkersForProject(projectId);
    _inFlight[key] = future;

    try {
      final data = await future;
      _cache[key] = _CacheEntry(value: data, cachedAt: DateTime.now());
      return data;
    } finally {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _requestWorkersForProject(
    int projectId,
  ) async {
    final byId = <int, Map<String, dynamic>>{};

    // Source 1: assignment-aware worker set (includes subtask assignments).
    try {
      final response = await http.get(
        AppConfig.apiUri('attendance/supervisor-overview/?project_id=$projectId'),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['field_workers'] is List) {
          final workers = (decoded['field_workers'] as List<dynamic>)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);

          for (final worker in workers) {
            final rawId = worker['fieldworker_id'] ?? worker['id'];
            final workerId = rawId is int
                ? rawId
                : int.tryParse(rawId?.toString() ?? '');
            if (workerId == null) continue;
            byId[workerId] = worker;
          }
        }
      }
    } catch (_) {
      // Continue with direct worker endpoint fallback.
    }

    // Source 2: direct workers endpoint (often richer payload fields).
    try {
      final directWorkers = await _requestCollection(
        'field-workers/?project_id=$projectId',
      );
      for (final worker in directWorkers) {
        final rawId = worker['fieldworker_id'] ?? worker['id'];
        final workerId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        if (workerId == null) continue;
        byId[workerId] = worker;
      }
    } catch (_) {
      // Keep whatever data we already collected.
    }

    return byId.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> fetchPhasesForProject(
    int projectId,
  ) {
    return _fetchCollection(
      key: 'phases:$projectId',
      endpoint: 'phases/?project_id=$projectId',
    );
  }

  static Future<List<Map<String, dynamic>>> fetchSubtasksForPhase(
    int phaseId,
  ) {
    return _fetchCollection(
      key: 'subtasks:$phaseId',
      endpoint: 'subtasks/?phase_id=$phaseId',
    );
  }

  static Future<List<Map<String, dynamic>>> _fetchCollection({
    required String key,
    required String endpoint,
  }) async {
    final now = DateTime.now();
    final cached = _cache[key];
    if (cached != null && now.difference(cached.cachedAt) <= _ttl) {
      return cached.value;
    }

    final existing = _inFlight[key];
    if (existing != null) {
      return existing;
    }

    final future = _requestCollection(endpoint);
    _inFlight[key] = future;

    try {
      final data = await future;
      _cache[key] = _CacheEntry(value: data, cachedAt: DateTime.now());
      return data;
    } finally {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _requestCollection(
    String endpoint,
  ) async {
    try {
      final response = await http.get(AppConfig.apiUri(endpoint));
      if (response.statusCode != 200) return <Map<String, dynamic>>[];

      final decoded = jsonDecode(response.body);
      final raw = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['results'] is List
                ? decoded['results'] as List<dynamic>
                : (decoded is Map<String, dynamic> && decoded['data'] is List
                      ? decoded['data'] as List<dynamic>
                      : const <dynamic>[]));

      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime cachedAt;

  const _CacheEntry({required this.value, required this.cachedAt});
}
