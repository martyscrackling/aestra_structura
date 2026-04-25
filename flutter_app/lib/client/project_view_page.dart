import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_config.dart';
import '../services/auth_service.dart';
import 'models/project_item.dart';

class ProjectViewPage extends StatefulWidget {
  const ProjectViewPage({super.key, required this.project});

  final ProjectItem project;

  @override
  State<ProjectViewPage> createState() => _ProjectViewPageState();
}

class _ProjectViewPageState extends State<ProjectViewPage> {
  late Future<List<_PhaseSection>> _future;
  final Map<int, TextEditingController> _phaseReviewControllers = {};
  List<_BackJobReviewItem> _reviews = [];
  bool _isLoadingReviews = true;
  int? _submittingPhaseId;
  String? _reviewsError;

  @override
  void initState() {
    super.initState();
    _future = _load().then((sections) {
      if (mounted) {
        setState(() => _syncPhaseReviewControllers(sections));
      }
      return sections;
    });
    _loadBackJobReviews();
  }

  @override
  void dispose() {
    for (final c in _phaseReviewControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncPhaseReviewControllers(List<_PhaseSection> sections) {
    final ids = sections.map((s) => s.phaseId).toSet();
    for (final id in _phaseReviewControllers.keys.toList()) {
      if (!ids.contains(id)) {
        _phaseReviewControllers.remove(id)?.dispose();
      }
    }
    for (final s in sections) {
      _phaseReviewControllers.putIfAbsent(
        s.phaseId,
        () => TextEditingController(),
      );
    }
  }

  Future<List<_PhaseSection>> _load() async {
    final projectId = widget.project.projectId;
    if (projectId == 0) return const [];

    final response = await http.get(
      AppConfig.apiUri('phases/?project_id=$projectId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load phases');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('Unexpected phases response');

    final phases = decoded.whereType<Map<String, dynamic>>().toList();
    
    // Sort phases by createdAt (oldest first)
    phases.sort((a, b) {
      final aCreated = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
      final bCreated = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
      int cmp = aCreated.compareTo(bCreated);
      if (cmp == 0) {
        return (a['phase_id'] ?? 0).compareTo(b['phase_id'] ?? 0);
      }
      return cmp;
    });
    
    Map<String, dynamic>? latestPhase;
    DateTime? maxDate;
    for (final p in phases) {
      final d = DateTime.tryParse((p['updated_at'] as String?) ?? '');
      if (d != null) {
        if (maxDate == null || d.isAfter(maxDate)) {
          maxDate = d;
          latestPhase = p;
        }
      }
    }
    if (latestPhase == null && phases.isNotEmpty) {
      latestPhase = phases.last;
    }

    final sections = <_PhaseSection>[];

    for (final p in phases) {
      final title = (p['phase_name'] as String?) ?? 'Phase';
      final updatedAt = DateTime.tryParse((p['updated_at'] as String?) ?? '');
      final isLatestPhase = (p == latestPhase);

      final tasksRaw = (p['subtasks'] is List)
          ? (p['subtasks'] as List)
          : const [];
      final tasks = tasksRaw
          .whereType<Map<String, dynamic>>()
          .map((t) {
            final taskTitle = (t['title'] as String?) ?? 'Untitled task';
            final status = (t['status'] as String?) ?? 'pending';
            final progressNotes = t['progress_notes'] as String?;
            final updatePhotosRaw = (t['update_photos'] is List) ? (t['update_photos'] as List) : const [];
            final updatePhotos = updatePhotosRaw.whereType<Map<String, dynamic>>().toList(growable: false);
            final updatedAtStr = t['updated_at'] as String?;
            final updatedAtDt = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;

            return _TaskItem(
              title: taskTitle, 
              status: status,
              progressNotes: progressNotes,
              updatePhotos: updatePhotos,
              updatedAt: updatedAtDt,
            );
          })
          .toList(growable: false);

      final phaseId = (p['phase_id'] as num?)?.toInt() ?? 0;

      sections.add(
        _PhaseSection(
          phaseId: phaseId,
          title: title,
          date: _formatDateLabel(updatedAt),
          tasks: tasks,
          isLatestUpdatedPhase: isLatestPhase,
        ),
      );
    }

    return sections;
  }

  String _getImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final baseUri = Uri.parse(AppConfig.apiBaseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}$normalizedPath';
  }

  Widget _buildProjectHeaderImage({required String raw, required bool isMobile}) {
    final fallback = Container(
      height: isMobile ? 160 : 200,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
    );

    final imageUrl = raw.trim();
    if (imageUrl.isEmpty) return fallback;
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        height: isMobile ? 160 : 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return Image.network(
      _getImageUrl(imageUrl),
      height: isMobile ? 160 : 200,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  String _formatDateLabel(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Updated today';
    if (diff.inDays == 1) return 'Updated yesterday';
    return 'Updated ${diff.inDays} days ago';
  }

  Future<void> _loadBackJobReviews() async {
    final projectId = widget.project.projectId;
    if (projectId == 0) {
      setState(() {
        _reviews = [];
        _reviewsError = null;
        _isLoadingReviews = false;
      });
      return;
    }

    setState(() {
      _isLoadingReviews = true;
      _reviewsError = null;
    });

    try {
      final response = await http.get(
        AppConfig.apiUri('back-job-reviews/?project_id=$projectId'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load reviews');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw Exception('Unexpected reviews response');

      final reviews = decoded
          .whereType<Map<String, dynamic>>()
          .map(_BackJobReviewItem.fromJson)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviewsError = 'Unable to load back job reviews.';
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _submitBackJobReviewForPhase(int phaseId) async {
    final controller = _phaseReviewControllers[phaseId];
    final reviewText = (controller?.text ?? '').trim();
    if (reviewText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter feedback for this phase before submitting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUser = AuthService().currentUser;
    final clientIdRaw = currentUser?['client_id'] ?? currentUser?['user_id'];
    final clientId = int.tryParse('$clientIdRaw');
    final userId = int.tryParse('${currentUser?['user_id']}');
    final projectId = widget.project.projectId;

    if (clientId == null || projectId == 0 || phaseId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit feedback: missing client, project, or phase.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _submittingPhaseId = phaseId;
    });

    try {
      final response = await http.post(
        AppConfig.apiUri('back-job-reviews/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'project': projectId,
          'client': clientId,
          'client_user_id': userId,
          'review_text': reviewText,
          'phase': phaseId,
        }),
      );

      if (response.statusCode == 201) {
        controller?.clear();
        await _loadBackJobReviews();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback for this phase was sent to your project team.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String detail = 'Failed to submit feedback (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            detail = decoded['detail'].toString();
          }
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error submitting feedback.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingPhaseId = null;
        });
      }
    }
  }

  String _formatReviewDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  void _showTasksModal(BuildContext context, _PhaseSection week) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? screenWidth * 0.9 : 700,
            maxHeight: isMobile
                ? MediaQuery.of(context).size.height * 0.7
                : 520,
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        week.title,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Subtasks',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: week.tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = week.tasks[index];
                      final dotColor = switch (t.status.toLowerCase()) {
                        'completed' => Colors.green,
                        'in_progress' || 'in progress' => Colors.blue,
                        _ => Colors.orange,
                      };
                      List<Map<String, dynamic>> latestUpdatePhotos = [];
                      if (t.updatePhotos.isNotEmpty && t.updatedAt != null) {
                        final firstPhotoRaw = t.updatePhotos.first['created_at'] as String?;
                        final firstPhotoDt = firstPhotoRaw != null ? DateTime.tryParse(firstPhotoRaw) : null;
                        
                        if (firstPhotoDt != null) {
                          final diff = t.updatedAt!.difference(firstPhotoDt).inMinutes.abs();
                          if (diff < 2) {
                            String? getGroupKey(DateTime? dt) {
                              if (dt == null) return null;
                              final localDt = dt.toLocal();
                              final dateStr = '${localDt.day}/${localDt.month}/${localDt.year}';
                              String hour = localDt.hour > 12 ? '${localDt.hour - 12}' : '${localDt.hour}';
                              if (hour == '0') hour = '12';
                              final minute = localDt.minute.toString().padLeft(2, '0');
                              final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
                              return '$dateStr at $hour:$minute $ampm';
                            }
                            
                            final firstKey = getGroupKey(firstPhotoDt);
                            latestUpdatePhotos = t.updatePhotos.where((p) {
                              final pRaw = p['created_at'] as String?;
                              final pDt = pRaw != null ? DateTime.tryParse(pRaw) : null;
                              return getGroupKey(pDt) == firstKey;
                            }).toList();
                          }
                        }
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.title,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: dotColor.withAlpha(20),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: dotColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (t.updatedAt != null) Builder(builder: (context) {
                              final localDt = t.updatedAt!.toLocal();
                              final dateStr = '${localDt.day}/${localDt.month}/${localDt.year}';
                              String hour = localDt.hour > 12 ? '${localDt.hour - 12}' : '${localDt.hour}';
                              if (hour == '0') hour = '12';
                              final minute = localDt.minute.toString().padLeft(2, '0');
                              final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Last Updated: $dateStr at $hour:$minute $ampm',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                ),
                              );
                            }),
                            if (t.progressNotes != null && t.progressNotes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              Text(t.progressNotes!, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            ],
                            if (latestUpdatePhotos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: latestUpdatePhotos.map((photoItem) {
                                  final photoPath = photoItem['photo'] as String?;
                                  if (photoPath == null) return const SizedBox.shrink();
                                  final photoUrl = _getImageUrl(photoPath);
                                  
                                  return GestureDetector(
                                    onTap: () => _showFullImage(context, photoUrl),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: Image.network(
                                          photoUrl,
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            height: 100,
                                            width: 100,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.broken_image, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showHistoryModal(context, t),
                                icon: const Icon(Icons.history, size: 16, color: Color(0xFFFF7A18)),
                                label: const Text(
                                  'History',
                                  style: TextStyle(color: Color(0xFFFF7A18), fontSize: 13),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
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
        ),
      ),
    );
  }

  void _showHistoryModal(BuildContext context, _TaskItem t) {
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: Builder(builder: (context) {
                      final Map<String, List<Map<String, dynamic>>> groupedUpdates = {};
                      for (final photoItem in t.updatePhotos) {
                        final rawDate = photoItem['created_at'] as String?;
                        DateTime? dt;
                        if (rawDate != null) dt = DateTime.tryParse(rawDate);

                        String dateStr = '';
                        String timeStr = '';
                        if (dt != null) {
                          final localDt = dt.toLocal();
                          dateStr = '${localDt.day}/${localDt.month}/${localDt.year}';
                          String hour = localDt.hour > 12 ? '${localDt.hour - 12}' : '${localDt.hour}';
                          if (hour == '0') hour = '12';
                          final minute = localDt.minute.toString().padLeft(2, '0');
                          final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
                          timeStr = '$hour:$minute $ampm';
                        }
                        
                        final key = dateStr.isNotEmpty ? '$dateStr at $timeStr' : 'Unknown Date';
                        groupedUpdates.putIfAbsent(key, () => []).add(photoItem);
                      }
                      
                      if (t.updatedAt != null) {
                        final localDt = t.updatedAt!.toLocal();
                        final dateStr = '${localDt.day}/${localDt.month}/${localDt.year}';
                        String hour = localDt.hour > 12 ? '${localDt.hour - 12}' : '${localDt.hour}';
                        if (hour == '0') hour = '12';
                        final minute = localDt.minute.toString().padLeft(2, '0');
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
                          child: Text('No history available.', style: TextStyle(color: Colors.grey)),
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
                            if (p['progress_notes'] != null && p['progress_notes'].toString().isNotEmpty) {
                              notes = p['progress_notes'].toString();
                              break;
                            }
                          }
                          if (notes == null && index == 0 && t.progressNotes != null && t.progressNotes!.isNotEmpty) {
                            notes = t.progressNotes;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                key, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)
                              ),
                              if (notes != null) ...[
                                const SizedBox(height: 4),
                                Text('Notes: $notes', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                              ],
                              if (photos.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: photos.map((photoItem) {
                                    final photoPath = photoItem['photo'] as String?;
                                    if (photoPath == null) return const SizedBox.shrink();
                                    final photoUrl = _getImageUrl(photoPath);
                                    
                                    return GestureDetector(
                                      onTap: () => _showFullImage(context, photoUrl),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(7),
                                          child: Image.network(
                                            photoUrl,
                                            height: 80,
                                            width: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              height: 80,
                                              width: 80,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.broken_image, color: Colors.grey),
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
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
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
                        child: Icon(Icons.broken_image, color: Colors.white, size: 50),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final project = widget.project;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          project.title,
          style: const TextStyle(color: Color(0xFF0C1935)),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<List<_PhaseSection>>(
        future: _future,
        builder: (context, snapshot) {
          final phases = snapshot.data ?? const <_PhaseSection>[];

          return RefreshIndicator(
            onRefresh: () async {
              final f = _load();
              setState(() {
                _future = f;
              });
              final sections = await f;
              await _loadBackJobReviews();
              if (!mounted) return;
              setState(() {
                _syncPhaseReviewControllers(sections);
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildProjectHeaderImage(
                      raw: project.imageUrl,
                      isMobile: isMobile,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    project.title,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C1935),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${project.startDate}  •  ${project.endDate}',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: project.progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            project.progress > 0.7
                                ? Colors.green
                                : project.progress > 0.4
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(project.progress * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFFFF7A18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(project.location)),
                    ],
                  ),
                  if (_isLoadingReviews)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_reviewsError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _reviewsError!,
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    )
                  else if (_reviews.where((r) => r.phaseId == null).isNotEmpty) ...[
                    Text(
                      'General project feedback',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Earlier messages not tied to a specific phase',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._reviews
                        .where((r) => r.phaseId == null)
                        .map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.clientName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatReviewDate(r.createdAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    r.reviewText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'To Do',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (snapshot.hasError)
                    const Text(
                      'Unable to load tasks.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    )
                  else if (phases.isEmpty)
                    const Text(
                      'No tasks found for this project.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    )
                  else
                    ...phases.map((w) {
                      final completed = w.tasks
                          .where((t) => t.status.toLowerCase() == 'completed')
                          .length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 16,
                              vertical: isMobile ? 10 : 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: isMobile ? 14 : 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  w.date,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text(
                                      '$completed/${w.tasks.length}',
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _showTasksModal(context, w),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF7A18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 12 : 16,
                                          vertical: isMobile ? 8 : 10,
                                        ),
                                      ),
                                      child: Text(
                                        'View more',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isMobile ? 12 : 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'Feedback for this phase',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Your supervisor and project manager can read this.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _phaseReviewControllers[w
                                      .phaseId],
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText:
                                        'What should we know about this phase?',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: _submittingPhaseId != null
                                        ? null
                                        : () => _submitBackJobReviewForPhase(
                                            w.phaseId,
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(
                                        0xFFFF7A18,
                                      ),
                                    ),
                                    child: _submittingPhaseId == w.phaseId
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Send feedback',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                if (_reviews
                                    .any((r) => r.phaseId == w.phaseId)) ...[
                                  const SizedBox(height: 10),
                                  ..._reviews
                                      .where((r) => r.phaseId == w.phaseId)
                                      .map(
                                        (r) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF9FAFB),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFE5E7EB),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      _formatReviewDate(
                                                        r.createdAt,
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                          0xFF6B7280,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  r.reviewText,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF374151),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhaseSection {
  _PhaseSection({
    required this.phaseId,
    required this.title,
    required this.date,
    required this.tasks,
    required this.isLatestUpdatedPhase,
  });
  final int phaseId;
  final String title;
  final String date;
  final List<_TaskItem> tasks;
  final bool isLatestUpdatedPhase;
}

class _TaskItem {
  _TaskItem({
    required this.title,
    required this.status,
    this.progressNotes,
    this.updatePhotos = const [],
    this.updatedAt,
  });
  final String title;
  final String status;
  final String? progressNotes;
  final List<Map<String, dynamic>> updatePhotos;
  final DateTime? updatedAt;
}

class _BackJobReviewItem {
  _BackJobReviewItem({
    required this.reviewId,
    this.phaseId,
    this.phaseName,
    required this.clientName,
    required this.reviewText,
    required this.createdAt,
    required this.isResolved,
  });

  final int reviewId;
  final int? phaseId;
  final String? phaseName;
  final String clientName;
  final String reviewText;
  final DateTime createdAt;
  final bool isResolved;

  factory _BackJobReviewItem.fromJson(Map<String, dynamic> json) {
    final rawPhase = json['phase'];
    int? phaseId;
    if (rawPhase is int) {
      phaseId = rawPhase;
    } else if (rawPhase is num) {
      phaseId = rawPhase.toInt();
    } else {
      phaseId = int.tryParse('${rawPhase ?? ''}');
    }
    if (phaseId == 0) phaseId = null;
    return _BackJobReviewItem(
      reviewId: (json['review_id'] as num?)?.toInt() ?? 0,
      phaseId: phaseId,
      phaseName: json['phase_name'] as String?,
      clientName: (json['client_name'] as String?) ?? 'Client',
      reviewText: (json['review_text'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
      isResolved: json['is_resolved'] == true,
    );
  }
}
