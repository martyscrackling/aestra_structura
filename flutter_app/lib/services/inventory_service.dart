import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class InventoryService {
  // ── List items ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getInventoryItems({
    required dynamic userId,
  }) async {
    final uri = AppConfig.apiUri('inventory-items/?user_id=$userId');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load inventory items (${response.statusCode})');
  }

  // ── List items visible to a supervisor ──────────────────────────────────
  static Future<List<Map<String, dynamic>>> getInventoryItemsForSupervisor({
    required dynamic supervisorId,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/?supervisor_id=$supervisorId',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load inventory items (${response.statusCode})');
  }

  // ── Add item ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addInventoryItem({
    required dynamic userId,
    required String name,
    required String category,
    String? serialNumber,
    int quantity = 1,
    String? location,
    String? notes,
    int? projectId,
  }) async {
    final uri = AppConfig.apiUri('inventory-items/?user_id=$userId');
    final body = <String, dynamic>{
      'name': name,
      'category': category,
      'quantity': quantity,
      'created_by': userId,
    };
    if (serialNumber != null && serialNumber.isNotEmpty) {
      body['serial_number'] = serialNumber;
    }
    if (location != null && location.isNotEmpty) body['location'] = location;
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    if (projectId != null) body['project_id'] = projectId;

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to add item (${response.statusCode}): ${response.body}',
    );
  }

  // ── Upload photo ────────────────────────────────────────────────────────
  static Future<String?> uploadItemPhoto({
    required int itemId,
    required dynamic userId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/$itemId/upload_photo/?user_id=$userId',
    );
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['url'] as String?;
    }
    throw Exception('Photo upload failed (${resp.statusCode})');
  }

  // ── Update item status (PATCH) ──────────────────────────────────────────
  static Future<Map<String, dynamic>> updateItemStatus({
    required int itemId,
    required String status,
    required dynamic userId,
  }) async {
    final uri = AppConfig.apiUri('inventory-items/$itemId/?user_id=$userId');
    final response = await http
        .patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update status (${response.statusCode})');
  }

  // ── Checkout an item to a supervisor ────────────────────────────────────
  static Future<Map<String, dynamic>> checkoutItem({
    required int itemId,
    required int supervisorId,
    required dynamic userId,
    int? fieldWorkerId,
    int? projectId,
    String? expectedReturnDate,
    String? notes,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/$itemId/checkout/?supervisor_id=$supervisorId',
    );
    final body = <String, dynamic>{'supervisor_id': supervisorId};
    if (fieldWorkerId != null) body['field_worker_id'] = fieldWorkerId;
    if (projectId != null) body['project_id'] = projectId;
    if (expectedReturnDate != null) {
      body['expected_return_date'] = expectedReturnDate;
    }
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Checkout failed (${response.statusCode}): ${response.body}',
    );
  }

  // ── Get field workers for a supervisor ──────────────────────────────────
  static Future<List<Map<String, dynamic>>> getFieldWorkersForSupervisor({
    required dynamic supervisorId,
    int? projectId,
  }) async {
    String qp = 'supervisor_id=$supervisorId';
    if (projectId != null) qp += '&project_id=$projectId';
    final uri = AppConfig.apiUri('field-workers/?$qp');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load field workers (${response.statusCode})');
  }

  // ── Get projects for a supervisor ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getProjectsForSupervisor({
    required dynamic supervisorId,
  }) async {
    final uri = AppConfig.apiUri('projects/?supervisor_id=$supervisorId');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load projects (${response.statusCode})');
  }

  // ── Get projects for a PM ───────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getProjectsForPM({
    required dynamic userId,
  }) async {
    final uri = AppConfig.apiUri('projects/?user_id=$userId');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load projects (${response.statusCode})');
  }

  // ── Return item ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> returnItem({
    required int itemId,
    dynamic userId,
    dynamic supervisorId,
  }) async {
    final qp = userId != null
        ? 'user_id=$userId'
        : 'supervisor_id=$supervisorId';
    final uri = AppConfig.apiUri('inventory-items/$itemId/return_item/?$qp');
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Return failed (${response.statusCode}): ${response.body}');
  }

  // ── Get active usages (currently checked out) ──────────────────────────
  static Future<List<Map<String, dynamic>>> getActiveUsages({
    dynamic userId,
    dynamic supervisorId,
  }) async {
    String qp = 'status=Checked Out';
    if (userId != null) qp += '&user_id=$userId';
    if (supervisorId != null) qp += '&supervisor_id=$supervisorId';
    final uri = AppConfig.apiUri('inventory-usage/?$qp');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load usages (${response.statusCode})');
  }

  // ── Delete item ─────────────────────────────────────────────────────────
  static Future<void> deleteItem({
    required int itemId,
    required dynamic userId,
  }) async {
    final uri = AppConfig.apiUri('inventory-items/$itemId/?user_id=$userId');
    final response = await http
        .delete(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(
        'Failed to delete item (${response.statusCode}): ${response.body}',
      );
    }
  }
}
