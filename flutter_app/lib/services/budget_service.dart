import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';

/// Thrown by BudgetService when the backend returns a validation error
/// (400) or any other non-2xx status. The [message] is already
/// user-friendly (either the `error` string or a flattened serializer
/// error).
class BudgetApiException implements Exception {
  final int statusCode;
  final String message;

  BudgetApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Client for the Step-3 budget endpoints:
///   PATCH `/projects/{id}/set-budget/`
///   GET   `/projects/{id}/budget-summary/`
///   PATCH `/phases/{id}/allocate-budget/`
///   POST  `/phases/{id}/record-usage/`
///   GET   `/phases/{id}/planned-vs-actual/`
///   CRUD  `/phase-material-plans/`
class BudgetService {
  static const Duration _timeout = Duration(seconds: 30);
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  // ── Project budget ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> setProjectBudget({
    required int projectId,
    required num budget,
  }) async {
    final uri = AppConfig.apiUri('projects/$projectId/set-budget/');
    final response = await http
        .patch(uri, headers: _jsonHeaders, body: jsonEncode({'budget': budget}))
        .timeout(_timeout);
    return _ok(response, 'set project budget');
  }

  static Future<Map<String, dynamic>> getBudgetSummary({
    required int projectId,
  }) async {
    final uri = AppConfig.apiUri('projects/$projectId/budget-summary/');
    final response = await http.get(uri).timeout(_timeout);
    return _ok(response, 'load budget summary');
  }

  // ── Phase allocation ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> allocatePhaseBudget({
    required int phaseId,
    required num allocatedBudget,
  }) async {
    final uri = AppConfig.apiUri('phases/$phaseId/allocate-budget/');
    final response = await http
        .patch(
          uri,
          headers: _jsonHeaders,
          body: jsonEncode({'allocated_budget': allocatedBudget}),
        )
        .timeout(_timeout);
    return _ok(response, 'allocate phase budget');
  }

  // ── Supervisor: record material usage ───────────────────────────────

  static Future<Map<String, dynamic>> recordMaterialUsage({
    required int phaseId,
    required int inventoryItemId,
    required int quantity,
    required int supervisorId,
    int? fieldWorkerId,
    String? notes,
  }) async {
    final uri = AppConfig.apiUri('phases/$phaseId/record-usage/');
    final body = <String, dynamic>{
      'inventory_item': inventoryItemId,
      'quantity': quantity,
      'supervisor_id': supervisorId,
    };
    if (fieldWorkerId != null) body['field_worker_id'] = fieldWorkerId;
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    final response = await http
        .post(uri, headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(_timeout);
    return _ok(response, 'record usage');
  }

  // ── Planned vs Actual ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPlannedVsActual({
    required int phaseId,
  }) async {
    final uri = AppConfig.apiUri('phases/$phaseId/planned-vs-actual/');
    final response = await http.get(uri).timeout(_timeout);
    return _ok(response, 'load planned-vs-actual');
  }

  // ── Phase Material Plans CRUD ───────────────────────────────────────

  static Future<List<Map<String, dynamic>>> listPhasePlans({
    int? phaseId,
    int? projectId,
  }) async {
    final params = <String>[];
    if (phaseId != null) params.add('phase_id=$phaseId');
    if (projectId != null) params.add('project_id=$projectId');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final uri = AppConfig.apiUri('phase-material-plans/$query');
    final response = await http.get(uri).timeout(_timeout);
    final decoded = _okRaw(response, 'list material plans');
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  static Future<Map<String, dynamic>> createPhasePlan({
    required int phaseId,
    required int inventoryItemId,
    required int plannedQuantity,
    int? subtaskId,
  }) async {
    final uri = AppConfig.apiUri('phase-material-plans/');
    final payload = <String, dynamic>{
      'phase': phaseId,
      'inventory_item': inventoryItemId,
      'planned_quantity': plannedQuantity,
    };
    if (subtaskId != null) {
      payload['subtask'] = subtaskId;
    }
    final response = await http
        .post(
          uri,
          headers: _jsonHeaders,
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    return _ok(response, 'create material plan');
  }

  static Future<Map<String, dynamic>> updatePhasePlan({
    required int planId,
    required int plannedQuantity,
  }) async {
    final uri = AppConfig.apiUri('phase-material-plans/$planId/');
    final response = await http
        .patch(
          uri,
          headers: _jsonHeaders,
          body: jsonEncode({'planned_quantity': plannedQuantity}),
        )
        .timeout(_timeout);
    return _ok(response, 'update material plan');
  }

  static Future<void> deletePhasePlan({required int planId}) async {
    final uri = AppConfig.apiUri('phase-material-plans/$planId/');
    final response = await http.delete(uri).timeout(_timeout);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw BudgetApiException(
        response.statusCode,
        _extractErrorMessage(response, fallback: 'delete material plan'),
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _ok(http.Response response, String action) {
    final decoded = _okRaw(response, action);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw BudgetApiException(
      response.statusCode,
      'Unexpected response shape from $action.',
    );
  }

  static dynamic _okRaw(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(response.body);
    }
    throw BudgetApiException(
      response.statusCode,
      _extractErrorMessage(response, fallback: action),
    );
  }

  /// Turn a Django/DRF error body into a single friendly string:
  ///   {"error": "..."}                 → "..."
  ///   {"field": ["message", ...]}      → "field: message"
  ///   {"non_field_errors": ["..."]}    → "..."
  static String _extractErrorMessage(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (decoded['error'] is String) return decoded['error'] as String;
        if (decoded['detail'] is String) return decoded['detail'] as String;
        final parts = <String>[];
        decoded.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            parts.add('$key: ${value.first}');
          } else if (value is String) {
            parts.add('$key: $value');
          }
        });
        if (parts.isNotEmpty) return parts.join('\n');
      }
      if (decoded is String && decoded.isNotEmpty) return decoded;
    } catch (_) {
      // fall through
    }
    return 'Failed to $fallback (${response.statusCode})';
  }
}
