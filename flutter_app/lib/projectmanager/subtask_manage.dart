import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/manage_workers.dart';
import 'phase_subtask_models.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';

class SubtaskManagePage extends StatefulWidget {
  final Phase phase;
  final bool viewOnly;

  /// After load, scroll this subtask into view (e.g. from a PM notification).
  final int? focusSubtaskId;

  const SubtaskManagePage({
    super.key,
    required this.phase,
    this.viewOnly = false,
    this.focusSubtaskId,
  });

  @override
  State<SubtaskManagePage> createState() => _SubtaskManagePageState();
}

class _SubtaskManagePageState extends State<SubtaskManagePage> {
  late Phase _phase;
  bool _isLoading = false;
  final GlobalKey _focusSubtaskKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _phase = widget.phase;
    if (widget.focusSubtaskId != null) {
      void scrollTo() {
        if (!mounted) return;
        final c = _focusSubtaskKey.currentContext;
        if (c != null) {
          Scrollable.ensureVisible(
            c,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.15,
          );
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollTo();
        Future<void>.delayed(
          const Duration(milliseconds: 300),
          scrollTo,
        );
      });
    }
  }

  bool get _viewOnly => widget.viewOnly;

  Future<void> _refreshPhase() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        AppConfig.apiUri('phases/${_phase.phaseId}/'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _phase = Phase.fromJson(jsonDecode(response.body));
        });
      }
    } catch (e) {
      debugPrint('Error refreshing phase: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editSubtask(Subtask subtask) async {
    final controller = TextEditingController(text: subtask.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Subtask Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter subtask name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A18),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != subtask.title) {
      try {
        final response = await http.patch(
          AppConfig.apiUri('subtasks/${subtask.subtaskId}/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': newTitle}),
        );
        if (response.statusCode == 200) {
          _refreshPhase();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Subtask updated')));
          }
        }
      } catch (e) {
        debugPrint('Error editing subtask: $e');
      }
    }
  }

  Future<void> _removeSubtask(Subtask subtask) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Subtask'),
        content: Text('Are you sure you want to remove "${subtask.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          AppConfig.apiUri('subtasks/${subtask.subtaskId}/'),
        );
        if (response.statusCode == 204) {
          _refreshPhase();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Subtask removed')));
          }
        }
      } catch (e) {
        debugPrint('Error removing subtask: $e');
      }
    }
  }

  Future<void> _addSubtask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subtask'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter subtask name'),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A18),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    final subtaskTitle = (title ?? '').trim();
    if (subtaskTitle.isEmpty) return;

    try {
      final response = await http.post(
        AppConfig.apiUri('subtasks/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phase': _phase.phaseId, 'title': subtaskTitle}),
      );

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _refreshPhase();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subtask added')),
        );
      } else {
        String detail = 'Failed to add subtask (${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final raw = decoded['detail'] ?? decoded['error'];
            if (raw != null) detail = raw.toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding subtask: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Projects'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Subtasks'),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshPhase,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button and phase header
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back),
                                color: const Color(0xFF0C1935),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _phase.phaseName,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0C1935),
                                      ),
                                    ),
                                    if (_phase.description != null &&
                                        _phase.description!.isNotEmpty)
                                      Text(
                                        _phase.description!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_viewOnly) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Read-only (completed project) — view subtasks and field updates only.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Phase info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 18,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Duration: ${_phase.daysDuration != null ? '${_phase.daysDuration} days' : 'Not set'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                if (_phase.status != 'not_started')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusBgColor(_phase.status),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _phase.status
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _getStatusColor(_phase.status),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Subtasks section
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Subtasks / ${_phase.subtasks.length}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0C1935),
                                  ),
                                ),
                              ),
                              if (!_viewOnly)
                                ElevatedButton.icon(
                                  onPressed: _addSubtask,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF7A18),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Subtask'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_phase.subtasks.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.checklist_outlined,
                                      size: 48,
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No subtasks yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: _phase.subtasks.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final subtask = entry.value;
                                  final isLast =
                                      index == _phase.subtasks.length - 1;
                                  final focus = widget.focusSubtaskId != null &&
                                      subtask.subtaskId ==
                                          widget.focusSubtaskId;
                                  return Column(
                                    key: focus
                                        ? _focusSubtaskKey
                                        : ValueKey<int>(subtask.subtaskId),
                                    children: [
                                      _SubtaskTile(
                                        subtask: subtask,
                                        phase: _phase,
                                        viewOnly: _viewOnly,
                                        highlight: focus,
                                        onEdit: () => _editSubtask(subtask),
                                        onRemove: () => _removeSubtask(subtask),
                                      ),
                                      if (!isLast)
                                        const Divider(
                                          height: 1,
                                          color: Color(0xFFF3F4F6),
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFFFF7A18);
      case 'not_started':
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFFE5F8ED);
      case 'in_progress':
        return const Color(0xFFFFF2E8);
      case 'not_started':
      default:
        return const Color(0xFFF3F4F6);
    }
  }
}

String _subtaskManagerImageUrl(String path) {
  if (path.startsWith('http')) return path;
  final baseUri = Uri.parse(AppConfig.apiBaseUrl);
  return '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}$path';
}

List<Map<String, dynamic>> _subtaskManagerLatestUpdatePhotos(Subtask t) {
  if (t.updatePhotos.isEmpty || t.updatedAt == null) return const [];
  final firstPhotoRaw = t.updatePhotos.first['created_at'] as String?;
  final firstPhotoDt = firstPhotoRaw != null
      ? DateTime.tryParse(firstPhotoRaw)
      : null;
  if (firstPhotoDt == null) return t.updatePhotos;

  final diff = t.updatedAt!.difference(firstPhotoDt).inMinutes.abs();
  if (diff >= 2) return t.updatePhotos;

  String? getGroupKey(DateTime? dt) {
    if (dt == null) return null;
    final localDt = dt.toLocal();
    final dateStr = '${localDt.day}/${localDt.month}/${localDt.year}';
    String hour = localDt.hour > 12
        ? '${localDt.hour - 12}'
        : '${localDt.hour}';
    if (hour == '0') hour = '12';
    final minute = localDt.minute.toString().padLeft(2, '0');
    final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
    return '$dateStr at $hour:$minute $ampm';
  }

  final firstKey = getGroupKey(firstPhotoDt);
  return t.updatePhotos.where((p) {
    final pRaw = p['created_at'] as String?;
    final pDt = pRaw != null ? DateTime.tryParse(pRaw) : null;
    return getGroupKey(pDt) == firstKey;
  }).toList();
}

/// True when the supervisor/field has left something to show (not [updatedAt] alone).
bool _subtaskHasMeaningfulFieldContent(Subtask t) {
  if ((t.progressNotes ?? '').trim().isNotEmpty) {
    return true;
  }
  for (final p in t.updatePhotos) {
    final path = p['photo'];
    if (path != null && path.toString().trim().isNotEmpty) {
      return true;
    }
  }
  return false;
}

void _subtaskManagerShowFullImage(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _subtaskManagerShowUpdateHistory(BuildContext context, Subtask t) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Update History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final Map<String, List<Map<String, dynamic>>>
                      groupedUpdates = {};
                      for (final photoItem in t.updatePhotos) {
                        final rawDate = photoItem['created_at'] as String?;
                        DateTime? dt;
                        if (rawDate != null) dt = DateTime.tryParse(rawDate);

                        String dateStr = '';
                        String timeStr = '';
                        if (dt != null) {
                          final localDt = dt.toLocal();
                          dateStr =
                              '${localDt.day}/${localDt.month}/${localDt.year}';
                          String hour = localDt.hour > 12
                              ? '${localDt.hour - 12}'
                              : '${localDt.hour}';
                          if (hour == '0') hour = '12';
                          final minute = localDt.minute.toString().padLeft(
                            2,
                            '0',
                          );
                          final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
                          timeStr = '$hour:$minute $ampm';
                        }

                        final key = dateStr.isNotEmpty
                            ? '$dateStr at $timeStr'
                            : 'Unknown Date';
                        groupedUpdates
                            .putIfAbsent(key, () => [])
                            .add(photoItem);
                      }

                      if (t.updatedAt != null) {
                        final localDt = t.updatedAt!.toLocal();
                        final dateStr =
                            '${localDt.day}/${localDt.month}/${localDt.year}';
                        String hour = localDt.hour > 12
                            ? '${localDt.hour - 12}'
                            : '${localDt.hour}';
                        if (hour == '0') hour = '12';
                        final minute = localDt.minute.toString().padLeft(
                          2,
                          '0',
                        );
                        final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
                        final timeStr = '$hour:$minute $ampm';
                        final key = '$dateStr at $timeStr';

                        if (!groupedUpdates.containsKey(key)) {
                          final newMap = <String, List<Map<String, dynamic>>>{};
                          newMap[key] = [];
                          newMap.addAll(groupedUpdates);
                          groupedUpdates.clear();
                          groupedUpdates.addAll(newMap);
                        }
                      }

                      if (groupedUpdates.isEmpty) {
                        return const Center(
                          child: Text(
                            'No history available.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: groupedUpdates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final key = groupedUpdates.keys.elementAt(index);
                          final photos = groupedUpdates[key]!;

                          String? notes;
                          for (final p in photos) {
                            if (p['progress_notes'] != null &&
                                p['progress_notes'].toString().isNotEmpty) {
                              notes = p['progress_notes'].toString();
                              break;
                            }
                          }
                          if (notes == null &&
                              index == 0 &&
                              t.progressNotes != null &&
                              t.progressNotes!.isNotEmpty) {
                            notes = t.progressNotes;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                              if (notes != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Notes: $notes',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                              if (photos.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: photos.map((photoItem) {
                                    final photoPath =
                                        photoItem['photo'] as String?;
                                    if (photoPath == null)
                                      return const SizedBox.shrink();
                                    final photoUrl = _subtaskManagerImageUrl(
                                      photoPath,
                                    );

                                    return GestureDetector(
                                      onTap: () => _subtaskManagerShowFullImage(
                                        context,
                                        photoUrl,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          child: Image.network(
                                            photoUrl,
                                            height: 80,
                                            width: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  height: 80,
                                                  width: 80,
                                                  color: Colors.grey[200],
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SubtaskProgressPanel extends StatelessWidget {
  const _SubtaskProgressPanel({
    required this.subtask,
    required this.latestPhotos,
  });

  final Subtask subtask;
  final List<Map<String, dynamic>> latestPhotos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 16,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              const Text(
                'Field progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    _subtaskManagerShowUpdateHistory(context, subtask),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFFFF7A18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 16),
                    SizedBox(width: 4),
                    Text('Full history', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (subtask.updatedAt != null) ...[
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final localDt = subtask.updatedAt!.toLocal();
                final dateStr =
                    '${localDt.day}/${localDt.month}/${localDt.year}';
                String hour = localDt.hour > 12
                    ? '${localDt.hour - 12}'
                    : '${localDt.hour}';
                if (hour == '0') {
                  hour = '12';
                }
                final minute = localDt.minute.toString().padLeft(2, '0');
                final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
                return Row(
                  children: [
                    Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Last updated $dateStr at $hour:$minute $ampm',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          if (subtask.progressNotes != null &&
              subtask.progressNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Colors.grey[700],
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtask.progressNotes!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
          if (latestPhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: latestPhotos.map((photoItem) {
                final photoPath = photoItem['photo'] as String?;
                if (photoPath == null) {
                  return const SizedBox.shrink();
                }
                final photoUrl = _subtaskManagerImageUrl(photoPath);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        _subtaskManagerShowFullImage(context, photoUrl),
                    borderRadius: BorderRadius.circular(8),
                    child: Ink(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.network(
                          photoUrl,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: Colors.grey[200]!,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubtaskTile extends StatelessWidget {
  final Subtask subtask;
  final Phase phase;
  final bool viewOnly;
  final bool highlight;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _SubtaskTile({
    required this.subtask,
    required this.phase,
    this.viewOnly = false,
    this.highlight = false,
    required this.onEdit,
    required this.onRemove,
  });

  static ButtonStyle _iconActionStyle() {
    return IconButton.styleFrom(
      padding: const EdgeInsets.all(6),
      minimumSize: const Size(40, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFFFF7A18);
      case 'not_started':
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFFE5F8ED);
      case 'in_progress':
        return const Color(0xFFFFF2E8);
      case 'not_started':
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestUpdatePhotos = _subtaskManagerLatestUpdatePhotos(subtask);
    final hasProgress = _subtaskHasMeaningfulFieldContent(subtask);
    final assignmentLocked = phase.isWorkerAssignmentLocked;
    final isCompletedSubtask = subtask.status.toLowerCase().trim() == 'completed';
    final canManageWorkers = !assignmentLocked && !viewOnly && !isCompletedSubtask;

    return Container(
      decoration: highlight
          ? BoxDecoration(
              color: const Color(0x1AEA580C),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEA580C), width: 1.2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(subtask.status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtask.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(subtask.status),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtask.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0C1935),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  style: _iconActionStyle(),
                  onPressed: () {
                    final readOnlyWorkforceView =
                        assignmentLocked ||
                        subtask.status.toLowerCase().trim() == 'completed';
                    showDialog(
                      context: context,
                      builder: (context) => ViewWorkForceModal(
                        subtask: subtask,
                        readOnly: readOnlyWorkforceView,
                      ),
                    );
                  },
                  icon: const Icon(Icons.groups_outlined, size: 22),
                tooltip: assignmentLocked
                    ? 'View who worked on this subtask'
                    : 'View work force',
                color: const Color(0xFF0C1935),
              ),
              if (canManageWorkers)
                IconButton(
                  style: _iconActionStyle(),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          ManageWorkersModal(subtask: subtask, phase: phase),
                    );
                  },
                  icon: const Icon(Icons.person_add_outlined, size: 22),
                  tooltip: 'Manage workers',
                  color: const Color(0xFFFF7A18),
                ),
              if (!viewOnly)
                PopupMenuButton<String>(
                  tooltip: 'Options',
                  padding: EdgeInsets.zero,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Color(0xFF0C1935),
                          ),
                          SizedBox(width: 12),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Remove', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'remove') {
                      onRemove();
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Icon(Icons.more_vert, color: Color(0xFF6B7280)),
                  ),
                ),
            ],
          ),
          if (hasProgress) ...[
            const SizedBox(height: 4),
            _SubtaskProgressPanel(
              subtask: subtask,
              latestPhotos: latestUpdatePhotos,
            ),
          ],
        ],
        ),
      ),
    );
  }
}

// View Work Force Modal
class ViewWorkForceModal extends StatefulWidget {
  final Subtask subtask;

  /// When the parent phase is completed, assignments cannot be changed — hide removal.
  final bool readOnly;

  const ViewWorkForceModal({
    super.key,
    required this.subtask,
    this.readOnly = false,
  });

  @override
  State<ViewWorkForceModal> createState() => _ViewWorkForceModalState();
}

class _ViewWorkForceModalState extends State<ViewWorkForceModal> {
  List<Map<String, dynamic>> _assignedWorkers = [];
  bool _isLoading = true;
  String? _error;

  String _formatApiTime(String? value) {
    if (value == null || value.isEmpty) return '';
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final hour24 = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour24 == null || minute == null) return value;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = (hour24 % 12 == 0) ? 12 : hour24 % 12;
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteText $period';
  }

  String _buildShiftLabel(Map<String, dynamic> assignment) {
    final shiftStart = assignment['shift_start']?.toString();
    final shiftEnd = assignment['shift_end']?.toString();
    if ((shiftStart == null || shiftStart.isEmpty) ||
        (shiftEnd == null || shiftEnd.isEmpty)) {
      return 'No shift schedule set';
    }
    return '${_formatApiTime(shiftStart)} - ${_formatApiTime(shiftEnd)}';
  }

  bool _isMorningShift(Map<String, dynamic> worker) {
    final start = (worker['shift_start'] ?? '').toString();
    final end = (worker['shift_end'] ?? '').toString();
    return start.startsWith('08:00') && end.startsWith('12:00');
  }

  bool _isAfternoonShift(Map<String, dynamic> worker) {
    final start = (worker['shift_start'] ?? '').toString();
    final end = (worker['shift_end'] ?? '').toString();
    return start.startsWith('12:00') && end.startsWith('16:00');
  }

  Widget _buildAssignedWorkersList(List<Map<String, dynamic>> workers) {
    if (workers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No workers in this shift.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: workers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final worker = workers[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFFF7A18),
                child: Text(
                  worker['name'].toString().substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker['name'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.construction, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          worker['role'],
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          worker['phone'],
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          worker['shift_label'] ?? 'No shift schedule set',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F8ED),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Assigned',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove worker',
                  onPressed: () => _removeAssignedWorker(worker),
                  icon: const Icon(
                    Icons.person_remove,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchAssignedWorkers();
  }

  Future<void> _fetchAssignedWorkers() async {
    try {
      print(
        '🔍 Fetching assigned workers for subtask: ${widget.subtask.subtaskId}',
      );
      final response = await http.get(
        AppConfig.apiUri(
          'subtask-assignments/?subtask_id=${widget.subtask.subtaskId}&_cb='
          '${DateTime.now().millisecondsSinceEpoch}',
        ),
      );

      print('✅ Response status: ${response.statusCode}');
      print('✅ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> assignments = jsonDecode(response.body);
        print('📊 Assignments fetched: ${assignments.length}');

        // Fetch details for each assigned worker
        List<Map<String, dynamic>> workers = [];
        for (var assignment in assignments) {
          final userId = AuthService().currentUser?['user_id'];
          final workerResponse = await http.get(
            (userId != null)
                ? AppConfig.apiUri(
                    'field-workers/${assignment['field_worker']}/?user_id=$userId',
                  )
                : AppConfig.apiUri(
                    'field-workers/${assignment['field_worker']}/',
                  ),
          );

          if (workerResponse.statusCode == 200) {
            final workerData = jsonDecode(workerResponse.body);
            workers.add({
              'assignment_id': assignment['assignment_id'],
              'field_worker_id': assignment['field_worker'],
              'name': '${workerData['first_name']} ${workerData['last_name']}',
              'role': workerData['role'] ?? 'Field Worker',
              'phone': workerData['phone_number'] ?? 'N/A',
              'shift_start': assignment['shift_start'],
              'shift_end': assignment['shift_end'],
              'shift_label': _buildShiftLabel(assignment),
            });
          }
        }

        setState(() {
          _assignedWorkers = workers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load assigned workers';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching assigned workers: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeAssignedWorker(Map<String, dynamic> worker) async {
    if (widget.readOnly) return;
    final assignmentId = worker['assignment_id'];
    if (assignmentId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Missing assignment id.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove Worker'),
        content: Text('Remove ${worker['name']} from this subtask?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        AppConfig.apiUri('subtask-assignments/$assignmentId/'),
      );

      if (!mounted) return;

      if (response.statusCode == 204 || response.statusCode == 200) {
        setState(() {
          _assignedWorkers.removeWhere(
            (w) => w['assignment_id'].toString() == assignmentId.toString(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${worker['name']} removed from subtask')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove worker (${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error removing worker: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.readOnly
                              ? 'Who worked on this subtask'
                              : 'Assigned work force',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Subtask: ${widget.subtask.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        if (widget.readOnly) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Assignments are read-only for this phase — you can only view who was assigned.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
            // Worker list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Error: $_error',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _assignedWorkers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No workers assigned yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.readOnly
                                  ? 'No field workers were assigned to this subtask.'
                                  : 'Click "Manage workers" to assign field workers',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildAssignedWorkersList(_assignedWorkers),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.readOnly
                        ? '${_assignedWorkers.length} assigned worker'
                            '${_assignedWorkers.length != 1 ? 's' : ''} (read-only)'
                        : 'Total: ${_assignedWorkers.length} worker'
                            '${_assignedWorkers.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
