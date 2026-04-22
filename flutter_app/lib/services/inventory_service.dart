import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class InventoryService {
  static const Duration _supervisorLookupTtl = Duration(seconds: 60);
  static final Map<String, _InventoryListCacheEntry> _listCacheByKey =
      <String, _InventoryListCacheEntry>{};
  static final Map<String, Future<List<Map<String, dynamic>>>>
  _inFlightListByKey = <String, Future<List<Map<String, dynamic>>>>{};

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
    List<String>? serialNumbers,
    int quantity = 1,
    required double price,
    String? location,
    String? notes,
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
    if (serialNumbers != null && serialNumbers.isNotEmpty) {
      body['serial_numbers'] = serialNumbers;
    }
    if (price != null) body['price'] = price;
    if (location != null && location.isNotEmpty) body['location'] = location;
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

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

  // ── List units under a profile ─────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getInventoryUnits({
    required int itemId,
    required dynamic userId,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/$itemId/units/?user_id=$userId',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception(
      'Failed to load units (${response.statusCode}): ${response.body}',
    );
  }

  // ── Assign specific unit to a project ──────────────────────────────────
  static Future<Map<String, dynamic>> assignInventoryUnitToProject({
    required int itemId,
    required int unitId,
    required dynamic userId,
    int? projectId,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/$itemId/assign_unit/?user_id=$userId',
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'unit_id': unitId, 'project_id': projectId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to assign unit (${response.statusCode}): ${response.body}',
    );
  }

  // ── Update specific unit status ───────────────────────────────────────
  static Future<Map<String, dynamic>> setInventoryUnitStatus({
    required int itemId,
    required int unitId,
    required dynamic userId,
    required String status,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/$itemId/set_unit_status/?user_id=$userId',
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'unit_id': unitId, 'status': status}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to update unit status (${response.statusCode}): ${response.body}',
    );
  }

  // ── Increase units for a profile ───────────────────────────────────────
  static Future<Map<String, dynamic>> addUnitsToItem({
    required int itemId,
    required dynamic userId,
    required int count,
    List<String>? serialNumbers,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/$itemId/add_units/?user_id=$userId',
    );
    final body = <String, dynamic>{'count': count};
    if (serialNumbers != null && serialNumbers.isNotEmpty) {
      body['serial_numbers'] = serialNumbers;
    }

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to add units (${response.statusCode}): ${response.body}',
    );
  }

  // ── Decrease units for a profile ───────────────────────────────────────
  static Future<Map<String, dynamic>> removeUnitsFromItem({
    required int itemId,
    required dynamic userId,
    required int count,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/$itemId/remove_units/?user_id=$userId',
    );

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'count': count}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to remove units (${response.statusCode}): ${response.body}',
    );
  }

  // ── Fetch movement history for one unit ────────────────────────────────
  static Future<List<Map<String, dynamic>>> getInventoryUnitMovements({
    required int itemId,
    required int unitId,
    required dynamic userId,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/$itemId/unit_movements/?user_id=$userId&unit_id=$unitId',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception(
      'Failed to load unit history (${response.statusCode}): ${response.body}',
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
    int? unitId,
    int? projectId,
    String? expectedReturnDate,
    String? notes,
  }) async {
    final uri = AppConfig.apiUri(
      'inventory-items/$itemId/checkout/?supervisor_id=$supervisorId',
    );
    final body = <String, dynamic>{'supervisor_id': supervisorId};
    if (fieldWorkerId != null) body['field_worker_id'] = fieldWorkerId;
    if (unitId != null) body['unit_id'] = unitId;
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

    // Try to parse error response
    try {
      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final error = errorData['error'] ?? 'Unknown error';
      final details = errorData['details'] ?? '';
      final fullError = details.isNotEmpty ? '$error\n$details' : error;
      throw Exception('Checkout failed: $fullError (${response.statusCode})');
    } catch (e) {
      throw Exception(
        'Checkout failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  // ── Get field workers for a supervisor ──────────────────────────────────
  static Future<List<Map<String, dynamic>>> getFieldWorkersForSupervisor({
    required dynamic supervisorId,
    int? projectId,
  }) async {
    String qp = 'supervisor_id=$supervisorId';
    if (projectId != null) qp += '&project_id=$projectId';
    final endpoint = 'field-workers/?$qp';
    final cacheKey = 'supervisor-workers:$supervisorId:${projectId ?? 'all'}';

    return _getCachedList(
      cacheKey: cacheKey,
      endpoint: endpoint,
      errorPrefix: 'Failed to load field workers',
    );
  }

  // ── Get projects for a supervisor ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getProjectsForSupervisor({
    required dynamic supervisorId,
  }) async {
    final endpoint = 'projects/?supervisor_id=$supervisorId';
    final cacheKey = 'supervisor-projects:$supervisorId';

    return _getCachedList(
      cacheKey: cacheKey,
      endpoint: endpoint,
      errorPrefix: 'Failed to load projects',
    );
  }

  static Future<List<Map<String, dynamic>>> _getCachedList({
    required String cacheKey,
    required String endpoint,
    required String errorPrefix,
  }) async {
    final now = DateTime.now();
    final cached = _listCacheByKey[cacheKey];
    if (cached != null && now.difference(cached.cachedAt) <= _supervisorLookupTtl) {
      return cached.items;
    }

    final existing = _inFlightListByKey[cacheKey];
    if (existing != null) {
      return existing;
    }

    final request = _requestList(endpoint: endpoint, errorPrefix: errorPrefix);
    _inFlightListByKey[cacheKey] = request;

    try {
      final items = await request;
      _listCacheByKey[cacheKey] = _InventoryListCacheEntry(
        items: items,
        cachedAt: DateTime.now(),
      );
      return items;
    } finally {
      if (identical(_inFlightListByKey[cacheKey], request)) {
        _inFlightListByKey.remove(cacheKey);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _requestList({
    required String endpoint,
    required String errorPrefix,
  }) async {
    final uri = AppConfig.apiUri(endpoint);
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('$errorPrefix (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> && decoded['results'] is List
              ? decoded['results'] as List<dynamic>
              : (decoded is Map<String, dynamic> && decoded['data'] is List
                    ? decoded['data'] as List<dynamic>
                    : const <dynamic>[]));

    return rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
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
    int? unitId,
  }) async {
    final qp = userId != null
        ? 'user_id=$userId'
        : 'supervisor_id=$supervisorId';
    final uri = AppConfig.apiUri('inventory-items/$itemId/return_item/?$qp');
    final body = <String, dynamic>{};
    if (unitId != null) body['unit_id'] = unitId;
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

class _InventoryListCacheEntry {
  final List<Map<String, dynamic>> items;
  final DateTime cachedAt;

  const _InventoryListCacheEntry({required this.items, required this.cachedAt});
}
