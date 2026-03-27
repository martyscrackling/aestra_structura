import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';
import 'unit_history_modal.dart';

class AssignInventoryItemModal extends StatefulWidget {
  final int itemId;
  final String itemName;

  const AssignInventoryItemModal({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<AssignInventoryItemModal> createState() =>
      _AssignInventoryItemModalState();
}

class _AssignInventoryItemModalState extends State<AssignInventoryItemModal> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _units = [];
  String _query = '';
  bool _isLoading = true;
  int? _assigningUnitId;
  int? _updatingStatusUnitId;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final userId = AuthService().currentUser?['user_id'];
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final results = await Future.wait([
        InventoryService.getProjectsForPM(userId: userId),
        InventoryService.getInventoryUnits(
          itemId: widget.itemId,
          userId: userId,
        ),
      ]);

      final allProjects = results[0];
      final allUnits = results[1];

      allProjects.sort((a, b) {
        final aName = (a['project_name'] ?? '').toString().toLowerCase();
        final bName = (b['project_name'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });

      allUnits.sort((a, b) {
        final aCode = (a['unit_code'] ?? '').toString().toLowerCase();
        final bCode = (b['unit_code'] ?? '').toString().toLowerCase();
        return aCode.compareTo(bCode);
      });

      if (!mounted) return;
      setState(() {
        _projects = allProjects.cast<Map<String, dynamic>>();
        _units = allUnits.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUnits {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _units;

    return _units.where((unit) {
      final code = (unit['unit_code'] ?? '').toString().toLowerCase();
      final projectName = (unit['current_project_name'] ?? '')
          .toString()
          .toLowerCase();
      final assignmentState = projectName.trim().isEmpty
          ? 'unassigned'
          : 'assigned';
      return code.contains(query) ||
          projectName.contains(query) ||
          assignmentState.contains(query);
    }).toList();
  }

  bool _isAssigned(Map<String, dynamic> unit) {
    final projectName = (unit['current_project_name'] ?? '').toString().trim();
    return projectName.isNotEmpty;
  }

  List<Map<String, dynamic>> get _filteredUnassignedUnits {
    return _filteredUnits.where((unit) => !_isAssigned(unit)).toList();
  }

  List<Map<String, dynamic>> get _filteredAssignedUnits {
    return _filteredUnits.where(_isAssigned).toList();
  }

  int? _projectIdFromMap(Map<String, dynamic> project) {
    final raw = project['project_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  int? _unitIdFromMap(Map<String, dynamic> unit) {
    final raw = unit['unit_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  int? _currentProjectIdFromUnit(Map<String, dynamic> unit) {
    final raw = unit['current_project'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _assignProject({
    required Map<String, dynamic> unit,
    int? projectId,
  }) async {
    final unitId = _unitIdFromMap(unit);
    if (unitId == null) return;

    try {
      final userId = AuthService().currentUser?['user_id'];
      if (userId == null) {
        throw Exception('User not logged in');
      }

      setState(() => _assigningUnitId = unitId);

      final response = await InventoryService.assignInventoryUnitToProject(
        itemId: widget.itemId,
        unitId: unitId,
        userId: userId,
        projectId: projectId,
      );

      final updatedUnit = response['unit'];
      if (updatedUnit is Map<String, dynamic>) {
        final updatedUnitId = _unitIdFromMap(updatedUnit);
        if (updatedUnitId != null) {
          final nextUnits = [..._units];
          final idx = nextUnits.indexWhere(
            (u) => _unitIdFromMap(u) == updatedUnitId,
          );
          if (idx >= 0) {
            nextUnits[idx] = updatedUnit;
          }
          setState(() {
            _units = nextUnits;
            _assigningUnitId = null;
            _hasChanges = true;
          });
        }
      } else {
        setState(() => _assigningUnitId = null);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Unit assignment updated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigningUnitId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Assignment failed: $e')));
    }
  }

  Future<void> _showUnitHistory(Map<String, dynamic> unit) async {
    final unitId = _unitIdFromMap(unit);
    if (unitId == null) return;

    final unitCode = (unit['unit_code'] ?? 'Unknown Unit').toString();
    await showDialog<void>(
      context: context,
      builder: (ctx) => UnitHistoryModal(
        itemId: widget.itemId,
        unitId: unitId,
        unitCode: unitCode,
      ),
    );
  }

  Future<void> _updateUnitStatus({
    required Map<String, dynamic> unit,
    required String status,
  }) async {
    final unitId = _unitIdFromMap(unit);
    if (unitId == null) return;

    try {
      final userId = AuthService().currentUser?['user_id'];
      if (userId == null) {
        throw Exception('User not logged in');
      }

      setState(() => _updatingStatusUnitId = unitId);

      final response = await InventoryService.setInventoryUnitStatus(
        itemId: widget.itemId,
        unitId: unitId,
        userId: userId,
        status: status,
      );

      final updatedUnit = response['unit'];
      if (updatedUnit is Map<String, dynamic>) {
        final updatedUnitId = _unitIdFromMap(updatedUnit);
        if (updatedUnitId != null) {
          final nextUnits = [..._units];
          final idx = nextUnits.indexWhere(
            (u) => _unitIdFromMap(u) == updatedUnitId,
          );
          if (idx >= 0) {
            nextUnits[idx] = updatedUnit;
          }
          setState(() {
            _units = nextUnits;
            _updatingStatusUnitId = null;
            _hasChanges = true;
          });
        }
      } else {
        setState(() => _updatingStatusUnitId = null);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Unit status updated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingStatusUnitId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status update failed: $e')));
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFFD1FAE5);
      case 'maintenance':
        return const Color(0xFFFFEDD5);
      case 'unavailable':
        return const Color(0xFFFEE2E2);
      case 'checked out':
        return const Color(0xFFDBEAFE);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  Color _statusFg(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF047857);
      case 'maintenance':
        return const Color(0xFF9A3412);
      case 'unavailable':
        return const Color(0xFF991B1B);
      case 'checked out':
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFF374151);
    }
  }

  Widget _statusBadge(Map<String, dynamic> unit) {
    final raw = (unit['status'] ?? 'Available').toString();
    final status = raw.isEmpty ? 'Available' : raw;
    final unitId = _unitIdFromMap(unit);
    final isUpdating = unitId != null && _updatingStatusUnitId == unitId;
    final isCheckedOut = status.toLowerCase() == 'checked out';

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: isUpdating
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_statusFg(status)),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: _statusFg(status),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 14, color: _statusFg(status)),
              ],
            ),
    );

    if (isUpdating || isCheckedOut || unitId == null) {
      return badge;
    }

    return PopupMenuButton<String>(
      tooltip: 'Change unit status',
      onSelected: (value) => _updateUnitStatus(unit: unit, status: value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'available', child: Text('Available')),
        PopupMenuItem(value: 'unavailable', child: Text('Unavailable')),
      ],
      child: badge,
    );
  }

  Widget _unitRow(Map<String, dynamic> unit) {
    final unitCode = (unit['unit_code'] ?? 'Unknown Unit').toString();
    final unitId = _unitIdFromMap(unit);
    final currentProjectName = (unit['current_project_name'] ?? '')
        .toString()
        .trim();
    final unitStatus = (unit['status'] ?? '').toString().trim().toLowerCase();
    final isCheckedOut = unitStatus == 'checked out';
    final assigned = currentProjectName.isNotEmpty;
    final isAssigning = _assigningUnitId != null && _assigningUnitId == unitId;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFF7A18).withOpacity(0.12),
            child: const Icon(
              Icons.precision_manufacturing,
              color: Color(0xFFFF7A18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unitCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                if (assigned) ...[
                  Text(
                    'Project: $currentProjectName',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _statusBadge(unit),
                          OutlinedButton(
                            onPressed: unitId == null
                                ? null
                                : () => _showUnitHistory(unit),
                            child: const Text('History'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 190,
                      child: isAssigning
                          ? const Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : DropdownButtonFormField<int?>(
                              value: _currentProjectIdFromUnit(unit),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Project',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              items: [
                                ..._projects.map((project) {
                                  final projectId = _projectIdFromMap(project);
                                  final projectName =
                                      (project['project_name'] ??
                                              'Unnamed Project')
                                          .toString();
                                  if (projectId == null) {
                                    return null;
                                  }
                                  return DropdownMenuItem<int?>(
                                    value: projectId,
                                    child: Text(
                                      projectName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).whereType<DropdownMenuItem<int?>>(),
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('None'),
                                ),
                              ],
                              onChanged:
                                  (_assigningUnitId != null ||
                                      unitId == null ||
                                      isCheckedOut)
                                  ? null
                                  : (selectedProjectId) async {
                                      final currentProjectId =
                                          _currentProjectIdFromUnit(unit);
                                      if (currentProjectId ==
                                          selectedProjectId) {
                                        return;
                                      }
                                      await _assignProject(
                                        unit: unit,
                                        projectId: selectedProjectId,
                                      );
                                    },
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 24 : 32,
      ),
      child: Container(
        width: isMobile ? double.infinity : 620,
        constraints: BoxConstraints(maxHeight: isMobile ? 560 : 640),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Track Units: ${widget.itemName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_hasChanges ? 'updated' : null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText:
                            'Search units by code, assignment, or project',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          setState(() => _query = _searchController.text),
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A18),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUnits.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _units.isEmpty
                              ? 'No inventory units found for this item yet.'
                              : 'No units match your search.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      children: [
                        _sectionHeader(
                          'Unassigned',
                          _filteredUnassignedUnits.length,
                        ),
                        if (_filteredUnassignedUnits.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'No unassigned units found.',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ..._filteredUnassignedUnits.map(_unitRow),
                        const SizedBox(height: 12),
                        _sectionHeader(
                          'Assigned',
                          _filteredAssignedUnits.length,
                        ),
                        if (_filteredAssignedUnits.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'No assigned units found.',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ..._filteredAssignedUnits.map(_unitRow),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_hasChanges ? 'updated' : null),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
