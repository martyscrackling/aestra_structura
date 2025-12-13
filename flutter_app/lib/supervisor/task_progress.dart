import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'widgets/sidebar.dart';

class Subtask {
  Subtask({
    required this.id,
    required this.title,
    this.assignedWorkers = const [],
    this.status = 'Draft',
    this.photos = const [],
    this.notes = '',
  });

  final String id;
  String title;
  List<String> assignedWorkers;
  String status; // 'Draft' | 'In Progress' | 'Completed'
  List<XFile> photos;
  String notes;
}

class Phase {
  Phase({required this.id, required this.title, required this.subtasks});
  final String id;
  String title;
  List<Subtask> subtasks;
}

class TaskProgressPage extends StatefulWidget {
  const TaskProgressPage({super.key});

  @override
  State<TaskProgressPage> createState() => _TaskProgressPageState();
}

class _TaskProgressPageState extends State<TaskProgressPage> {
  final Color primary = const Color(0xFF1396E9);
  final Color neutral = const Color(0xFFF4F6F9);
  final ImagePicker _picker = ImagePicker();

  // sample workers (replace with your real source)
  final List<String> allWorkers = ['John Doe', 'Jane Smith', 'Carlos Reyes', 'Alice Brown', 'Maria Lopez'];

  // sample phases & subtasks (provided by PM)
  List<Phase> _phases = [
    Phase(id: 'p1', title: 'Phase 1 — Pre-Design', subtasks: [
      Subtask(id: 'p1s1', title: 'Site inspection', assignedWorkers: ['John Doe']),
      Subtask(id: 'p1s2', title: 'Survey setup', assignedWorkers: [], notes: 'Prepare equipment'),
    ]),
    Phase(id: 'p2', title: 'Phase 2 — Design', subtasks: [
      Subtask(id: 'p2s1', title: 'Architectural drawing', assignedWorkers: ['Jane Smith']),
      Subtask(id: 'p2s2', title: 'Structural review', assignedWorkers: []),
    ]),
  ];

  // compute phase progress as percent of subtasks completed
  int _phaseProgress(int pIndex) {
    final subs = _phases[pIndex].subtasks;
    if (subs.isEmpty) return 0;
    final completed = subs.where((s) => s.status == 'Completed').length;
    return ((completed / subs.length) * 100).round();
  }

  // pick one or multiple images and append to subtask photos
  Future<void> _pickPhotosForSubtask(int phaseIndex, int subtaskIndex) async {
    try {
      final List<XFile>? picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked != null && picked.isNotEmpty) {
        setState(() {
          _phases[phaseIndex].subtasks[subtaskIndex].photos = [
            ..._phases[phaseIndex].subtasks[subtaskIndex].photos,
            ...picked
          ];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick images')));
    }
  }

  // assign workers to a subtask (multi-select dialog)
  Future<void> _assignWorkersToSubtask(int phaseIndex, int subtaskIndex) async {
    final subtask = _phases[phaseIndex].subtasks[subtaskIndex];
    final temp = List<String>.from(subtask.assignedWorkers);
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Workers'),
        content: StatefulBuilder(builder: (c, setLocal) {
          return SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                children: allWorkers.map((w) {
                  final isSel = temp.contains(w);
                  return CheckboxListTile(
                    value: isSel,
                    title: Text(w),
                    onChanged: (v) => setLocal(() {
                      if (v == true) {
                        temp.add(w);
                      } else {
                        temp.remove(w);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, temp), child: const Text('Assign')),
        ],
      ),
    );

    if (picked != null) {
      setState(() => _phases[phaseIndex].subtasks[subtaskIndex].assignedWorkers = picked);
    }
  }

  // remove single photo from subtask
  void _removePhoto(int phaseIndex, int subtaskIndex, int photoIndex) {
    setState(() {
      _phases[phaseIndex].subtasks[subtaskIndex].photos.removeAt(photoIndex);
    });
  }

  // single subtask detail dialog (edit notes and status; progress tracked at phase level)
  void _openSubtaskDialog(int phaseIndex, int subtaskIndex) {
    final sub = _phases[phaseIndex].subtasks[subtaskIndex];
    final notesCtrl = TextEditingController(text: sub.notes);
    String status = sub.status;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sub.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Assigned: ${sub.assignedWorkers.join(', ')}', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                items: ['Draft', 'In Progress', 'Completed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => status = v ?? status,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                sub.notes = notesCtrl.text.trim();
                sub.status = status;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumb(int phaseIndex, int subtaskIndex, int photoIndex, XFile xfile) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<Uint8List>(
            future: xfile.readAsBytes(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return SizedBox(width: 120, height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              if (snap.hasError || snap.data == null) {
                return SizedBox(width: 120, height: 80, child: Center(child: Icon(Icons.broken_image)));
              }
              return Image.memory(snap.data!, width: 120, height: 80, fit: BoxFit.cover);
            },
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(phaseIndex, subtaskIndex, photoIndex),
            child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.close, size: 14, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // small KPI chip used in header
  Widget _miniKPI(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral,
      body: Row(
        children: [
          const Sidebar(activePage: 'Task Progress'),
          Expanded(
            child: Column(
              children: [
                // Creative white header with blue vertical accent on the left (keeps notification bell + AESTRA)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      // slim blue line in the left corner
                      Container(width: 4, height: 44, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          const Text('Task Progress', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0C1935))),
                          const SizedBox(height: 6),
                          StreamBuilder<DateTime>(
                            stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                            builder: (context, snap) {
                              final now = snap.data ?? DateTime.now();
                              final formatted = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                              return Text(formatted, style: TextStyle(fontSize: 13, color: Colors.grey[700]));
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      // KPIs
                      _miniKPI('Phases', '${_phases.length}', Icons.view_list, Colors.indigo),
                      const SizedBox(width: 12),
                      _miniKPI('Subtasks', '${_phases.fold<int>(0, (t,p)=>t+p.subtasks.length)}', Icons.task, Colors.teal),
                      const SizedBox(width: 16),
                      // Notification bell (kept)
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications opened (demo)'))),
                            icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.notifications_outlined, color: Color(0xFF0C1935))),
                          ),
                          Positioned(right: 6, top: 6, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(6)))),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // AESTRA account (kept)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'switch') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switch account (demo)')));
                          if (value == 'logout') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logout (demo)')));
                        },
                        offset: const Offset(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(value: 'switch', height: 48, child: Row(children: [Icon(Icons.swap_horiz, size: 18, color: Colors.black87), SizedBox(width: 12), Text('Switch Account')])),
                          const PopupMenuDivider(height: 1),
                          const PopupMenuItem<String>(value: 'logout', height: 48, child: Row(children: [Icon(Icons.logout, size: 18, color: Color(0xFFFF6B6B)), SizedBox(width: 12), Text('Logout', style: TextStyle(color: Color(0xFFFF6B6B)))])),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFE8D5F2), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text("A", style: TextStyle(color: Color(0xFFB088D9), fontSize: 18, fontWeight: FontWeight.w700)))),
                              const SizedBox(width: 8),
                              const Text('AESTRA', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0C1935))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // phases list
                          for (var pIndex = 0; pIndex < _phases.length; pIndex++) ...[
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_phases[pIndex].title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 6),
                                          LinearProgressIndicator(
                                            value: (_phaseProgress(pIndex) / 100),
                                            color: primary,
                                            backgroundColor: Colors.grey.shade200,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        '${_phaseProgress(pIndex)}%',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Column(
                                      children: [
                                        for (var sIndex = 0; sIndex < _phases[pIndex].subtasks.length; sIndex++) ...[
                                          Card(
                                            color: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(child: Text(_phases[pIndex].subtasks[sIndex].title, style: const TextStyle(fontWeight: FontWeight.w700))),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: _phases[pIndex].subtasks[sIndex].status == 'Completed' ? Colors.green.withOpacity(0.12) : Colors.blue.withOpacity(0.06),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(_phases[pIndex].subtasks[sIndex].status, style: TextStyle(color: _phases[pIndex].subtasks[sIndex].status == 'Completed' ? Colors.green : Colors.blue, fontWeight: FontWeight.w700)),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text('Assigned: ${_phases[pIndex].subtasks[sIndex].assignedWorkers.join(', ')}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      const SizedBox(width: 12), // spacing - progress tracked at phase level
                                                      IconButton(
                                                        icon: const Icon(Icons.group, color: Color(0xFF1396E9)),
                                                        onPressed: () => _assignWorkersToSubtask(pIndex, sIndex),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.photo_camera, color: Color(0xFF1396E9)),
                                                        onPressed: () => _pickPhotosForSubtask(pIndex, sIndex),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.edit, color: Colors.orange),
                                                        onPressed: () => _openSubtaskDialog(pIndex, sIndex),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  if (_phases[pIndex].subtasks[sIndex].photos.isNotEmpty)
                                                    SizedBox(
                                                      height: 90,
                                                      child: ListView.separated(
                                                        scrollDirection: Axis.horizontal,
                                                        itemCount: _phases[pIndex].subtasks[sIndex].photos.length,
                                                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                                                        itemBuilder: (context, photoIndex) {
                                                          final xfile = _phases[pIndex].subtasks[sIndex].photos[photoIndex];
                                                          return _buildPhotoThumb(pIndex, sIndex, photoIndex, xfile);
                                                        },
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        // Add Subtask removed — managed by Project Manager
                                        const SizedBox.shrink(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 24),
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
}