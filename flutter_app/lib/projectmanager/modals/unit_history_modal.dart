import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';

class UnitHistoryModal extends StatefulWidget {
  final int itemId;
  final int unitId;
  final String unitCode;

  const UnitHistoryModal({
    super.key,
    required this.itemId,
    required this.unitId,
    required this.unitCode,
  });

  @override
  State<UnitHistoryModal> createState() => _UnitHistoryModalState();
}

class _UnitHistoryModalState extends State<UnitHistoryModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  String _projectFromMovement(Map<String, dynamic> movement) {
    final toProject = (movement['to_project_name'] ?? '').toString().trim();
    if (toProject.isNotEmpty) return toProject;

    final fromProject = (movement['from_project_name'] ?? '').toString().trim();
    if (fromProject.isNotEmpty) return fromProject;

    return 'Unassigned';
  }

  List<Map<String, dynamic>> _limitToLastFiveProjects(
    List<Map<String, dynamic>> movements,
  ) {
    final recentProjects = <String>[];

    for (final movement in movements) {
      final projectName = _projectFromMovement(movement);
      if (projectName == 'Unassigned') continue;
      if (!recentProjects.contains(projectName)) {
        recentProjects.add(projectName);
      }
      if (recentProjects.length == 5) {
        break;
      }
    }

    if (recentProjects.isEmpty) {
      return movements.take(5).toList();
    }

    return movements.where((movement) {
      final projectName = _projectFromMovement(movement);
      return recentProjects.contains(projectName);
    }).toList();
  }

  Future<void> _loadHistory() async {
    try {
      final userId = AuthService().currentUser?['user_id'];
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final data = await InventoryService.getInventoryUnitMovements(
        itemId: widget.itemId,
        unitId: widget.unitId,
        userId: userId,
      );

      if (!mounted) return;
      setState(() {
        _history = _limitToLastFiveProjects(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load unit history: $e')),
      );
    }
  }

  IconData _iconForAction(String action) {
    switch (action.toLowerCase()) {
      case 'assigned':
        return Icons.add_link;
      case 'transferred':
        return Icons.swap_horiz;
      case 'checked out':
        return Icons.logout;
      case 'returned':
        return Icons.keyboard_return;
      default:
        return Icons.history;
    }
  }

  Color _colorForAction(String action) {
    switch (action.toLowerCase()) {
      case 'assigned':
        return const Color(0xFF0C1935);
      case 'transferred':
        return const Color(0xFFFF7A18);
      case 'checked out':
        return const Color(0xFFDC2626);
      case 'returned':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 24 : 32,
      ),
      child: Container(
        width: isMobile ? double.infinity : 640,
        constraints: BoxConstraints(maxHeight: isMobile ? 560 : 680),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit History: ${widget.unitCode}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Showing timeline for the last 5 projects',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _history.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'No movement history found for this unit yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final movement = _history[i];
                        final action = (movement['action'] ?? 'Status Updated')
                            .toString();
                        final fromProject =
                            (movement['from_project_name'] ?? '')
                                .toString()
                                .trim();
                        final toProject = (movement['to_project_name'] ?? '')
                            .toString()
                            .trim();
                        final notes = (movement['notes'] ?? '')
                            .toString()
                            .trim();
                        final createdAt = (movement['created_at'] ?? '')
                            .toString()
                            .trim();
                        final color = _colorForAction(action);

                        String directionText;
                        if (fromProject.isEmpty && toProject.isNotEmpty) {
                          directionText = 'Assigned to $toProject';
                        } else if (fromProject.isNotEmpty &&
                            toProject.isNotEmpty) {
                          directionText = '$fromProject -> $toProject';
                        } else if (fromProject.isNotEmpty) {
                          directionText = 'From $fromProject';
                        } else {
                          directionText = 'No project context';
                        }

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Icon(
                                  _iconForAction(action),
                                  size: 18,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      directionText,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        notes,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ],
                                    if (createdAt.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        createdAt,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
