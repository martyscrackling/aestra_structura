import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'widgets/sidebar.dart';

class DailyLogsPage extends StatefulWidget {
  const DailyLogsPage({super.key});

  @override
  State<DailyLogsPage> createState() => _DailyLogsPageState();
}

class _DailyLogsPageState extends State<DailyLogsPage> {
  final Color primary = const Color(0xFF1396E9);
  final Color neutral = const Color(0xFFF4F6F9);
  final Color darkAction = const Color(0xFF0C1935);

  // Example workers — replace with your real source if available
  final List<String> allWorkers = ['John Doe', 'Jane Smith', 'Carlos Reyes', 'Alice Brown'];

  // Form state
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  List<String> selectedWorkers = [];
  // store picked files as XFile so we can support single or multiple picks and web/mobile rendering
  List<XFile> photos = [];

  // store logs with status ('Draft' or 'Submitted')
  List<Map<String, dynamic>> logs = [];

  final ImagePicker _picker = ImagePicker();

  // Pick images directly (multi-select where supported). Adds to current selection.
  Future<void> _pickPhotos() async {
    try {
      // pickMultiImage allows selecting one or many depending on platform/gallery UI
      final List<XFile>? picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked != null && picked.isNotEmpty) {
        setState(() => photos.addAll(picked));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick images')));
    }
  }

  // Save current form as Submitted (requires >= 3 photos)
  void _submitToPM() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (selectedWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one worker')));
      return;
    }
    // no minimum photo requirement anymore

    final entry = {
      'time': _timeNow(),
      'worker': selectedWorkers.join(', '),
      'task': _taskController.text.trim(),
      'details': _detailsController.text.trim(),
      'photos': List<XFile>.from(photos),
      'status': 'Submitted',
    };

    setState(() {
      logs.insert(0, entry);
      _taskController.clear();
      _detailsController.clear();
      selectedWorkers.clear();
      photos.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted to PM')));
  }

  // Save current form as Draft (no photo requirement)
  void _saveDraft() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (selectedWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one worker')));
      return;
    }

    final entry = {
      'time': _timeNow(),
      'worker': selectedWorkers.join(', '),
      'task': _taskController.text.trim(),
      'details': _detailsController.text.trim(),
      'photos': List<XFile>.from(photos),
      'status': 'Draft',
    };

    setState(() {
      logs.insert(0, entry);
      _taskController.clear();
      _detailsController.clear();
      selectedWorkers.clear();
      photos.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
  }

  String _timeNow() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _taskController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  bool hasNotifications = true;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 1000;

    return Scaffold(
      backgroundColor: neutral,
      body: Row(
        children: [
          const Sidebar(activePage: "Daily Logs"),
          Expanded(
            child: Column(
              children: [
                // White header (keeps Notification bell and AESTRA) — redesigned with slim left accent
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  child: Row(
                    children: [
                      Container(width: 4, height: 44, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text('Daily Logs', style: TextStyle(color: Color(0xFF0C1935), fontSize: 20, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Create and review daily site logs', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                      const Spacer(),
                      // subtle KPI chips (creative)
                      _headerKPI('Drafts', '${0}', Colors.orange),
                      const SizedBox(width: 8),
                      _headerKPI('Submitted', '${0}', Colors.green),
                      const SizedBox(width: 12),
                      // notification bell
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() => hasNotifications = false);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications opened (demo)')));
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.notifications_outlined, color: Color(0xFF0C1935)),
                            ),
                          ),
                          if (hasNotifications)
                            Positioned(
                              right: 10,
                              top: 8,
                              child: Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(6))),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      // AESTRA account (switch/logout)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'switch') {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switch account (demo)')));
                          } else if (value == 'logout') {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logout (demo)')));
                          }
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
                              const SizedBox(width: 10),
                              const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text("AESTRA", style: TextStyle(color: Color(0xFF0C1935), fontSize: 13, fontWeight: FontWeight.w700)), Text("Supervisor", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w400))]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Main content: form + logs side-by-side on wide screens, stacked on narrow
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // left: form
                              Expanded(flex: 2, child: _buildFormCard()),
                              const SizedBox(width: 18),
                              // right: recent logs and stats
                              Expanded(flex: 1, child: _buildLogsPanel()),
                            ],
                          )
                        : Column(
                            children: [
                              _buildFormCard(),
                              const SizedBox(height: 14),
                              _buildLogsPanel(),
                            ],
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

  // small KPI used in header
  static Widget _headerKPI(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Row(children: [CircleAvatar(radius: 12, backgroundColor: color.withOpacity(0.12), child: Icon(Icons.circle, color: color, size: 12)), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color))])]),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // creative header row with accent and action group
            Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_road, color: Color(0xFF1396E9))),
                const SizedBox(width: 12),
                const Expanded(child: Text('Task / Activity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                Row(
                  children: [
                    // Submit to PM (prominent)
                    InkWell(
                      onTap: _submitToPM,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [primary, primary.withOpacity(0.85)]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
                        child: Row(children: const [Icon(Icons.send, color: Colors.white, size: 16), SizedBox(width: 8), Text('Submit to PM', style: TextStyle(color: Colors.white))]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _saveDraft,
                      icon: const Icon(Icons.save, size: 14, color: Colors.orange),
                      label: const Text('Save Draft', style: TextStyle(color: Colors.orange, fontSize: 12)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(controller: _taskController, decoration: InputDecoration(hintText: 'Brief task title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter task title' : null),
            const SizedBox(height: 12),
            const Text('Details', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextFormField(controller: _detailsController, decoration: InputDecoration(hintText: 'Describe the work done, issues, materials used', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 4, validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter details' : null),
            const SizedBox(height: 12),
            const Text('Workers on Task', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    // open selection dialog
                    final List<String>? picked = await showDialog<List<String>>(
                      context: context,
                      builder: (context) {
                        final tempSelected = List<String>.from(selectedWorkers);
                        return AlertDialog(
                          title: const Text('Select Workers'),
                          content: StatefulBuilder(
                            builder: (context, setState) {
                              return SizedBox(
                                width: 320,
                                child: ListView(
                                  shrinkWrap: true,
                                  children: allWorkers.map((w) {
                                    final isSel = tempSelected.contains(w);
                                    return CheckboxListTile(
                                      value: isSel,
                                      title: Text(w),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            tempSelected.add(w);
                                          } else {
                                            tempSelected.remove(w);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, tempSelected), child: const Text('Add')),
                          ],
                        );
                      },
                    );

                    if (picked != null) {
                      setState(() => selectedWorkers = picked);
                    }
                  },
                  icon: const Icon(Icons.person_add, size: 18, color: Colors.white),
                  label: const Text('Add Workers', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
                const SizedBox(width: 12),
                Text('${selectedWorkers.length} assigned', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                // small actions group: pick photos + clear
                IconButton(onPressed: _pickPhotos, icon: const Icon(Icons.photo_library), tooltip: 'Pick Photos'),
                if (photos.isNotEmpty)
                  IconButton(
                    onPressed: () => setState(() => photos.clear()),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear Photos',
                  )
              ],
            ),
            const SizedBox(height: 8),
            if (selectedWorkers.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: selectedWorkers.map((w) => Chip(label: Text(w), onDeleted: () => setState(() => selectedWorkers.remove(w)))).toList(),
              ),
            const SizedBox(height: 12),
            const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(onPressed: _pickPhotos, icon: const Icon(Icons.photo_camera), label: const Text('Pick Photos'), style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(width: 12),
              Text('${photos.length} selected', style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            if (photos.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List>(
                          future: photos[i].readAsBytes(),
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return SizedBox(width: 160, height: 120, child: Center(child: CircularProgressIndicator()));
                            }
                            if (snap.hasError || snap.data == null) {
                              return SizedBox(width: 160, height: 120, child: Center(child: Icon(Icons.broken_image)));
                            }
                            return Image.memory(snap.data!, width: 160, height: 120, fit: BoxFit.cover);
                          },
                        ),
                      ),
                      Positioned(top: 6, right: 6, child: GestureDetector(onTap: () => setState(() => photos.removeAt(i)), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.close, size: 16, color: Colors.white)))),
                    ]);
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildLogsPanel() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('Submitted & Draft Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.filter_list)),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: logs.isEmpty
                ? Center(child: Text('No logs yet', style: TextStyle(color: Colors.grey[700])))
                : ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200),
                    itemBuilder: (context, i) {
                      final log = logs[i];
                      final isDraft = (log['status'] ?? '') == 'Draft';
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Material(
                          color: isDraft ? Colors.orange.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            leading: CircleAvatar(radius: 22, backgroundColor: isDraft ? Colors.orange.shade100 : Colors.green.shade100, child: Icon(isDraft ? Icons.edit : Icons.check_circle, color: isDraft ? Colors.orange : Colors.green)),
                            title: Text(log['task'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${log['worker'] ?? ''} • ${log['time'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: isDraft ? Colors.orange.withOpacity(0.12) : Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                child: Text(log['status'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isDraft ? Colors.orange : Colors.green)),
                              ),
                              if (isDraft) ...[
                                IconButton(onPressed: () => _editDraft(i), icon: const Icon(Icons.edit, size: 18)),
                                IconButton(onPressed: () => _showLogDetails(log), icon: const Icon(Icons.remove_red_eye, size: 18)),
                                ElevatedButton(onPressed: () => _submitDraft(i), child: const Text('Submit')),
                              ] else ...[
                                TextButton(onPressed: () => _showLogDetails(log), child: const Text('View')),
                              ]
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          // summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Summary', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total Logs', style: TextStyle(color: Colors.grey[700])),
                Text('${logs.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Drafts', style: TextStyle(color: Colors.grey[700])),
                Text('${logs.where((l) => (l['status'] ?? '') == 'Draft').length}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.orange)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Submitted', style: TextStyle(color: Colors.grey[700])),
                Text('${logs.where((l) => (l['status'] ?? '') == 'Submitted').length}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green)),
              ]),
            ]),
          )
        ]),
      ),
    );
  }

  // helper: load draft into form for editing
  void _editDraft(int index) {
    final log = logs[index];
    _taskController.text = log['task'] ?? '';
    _detailsController.text = log['details'] ?? '';
    selectedWorkers = List<String>.from(((log['worker'] ?? '') as String).split(', ').where((s) => s.isNotEmpty));
    photos = List<XFile>.from(log['photos'] ?? []);
    setState(() {
      logs.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft loaded for editing')));
  }

  // helper: mark a draft as submitted
  void _submitDraft(int index) {
    setState(() {
      logs[index]['status'] = 'Submitted';
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft submitted')));
  }

  // Open log (centered modal)
  void _showLogDetails(Map<String, dynamic> log) {
    final List<XFile> logPhotos = List<XFile>.from(log['photos'] ?? []);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 900,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // header row: title + close
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(log['task'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (log['status'] == 'Submitted') ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                log['status'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: (log['status'] == 'Submitted') ? Colors.green : Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(log['time'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Details', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(log['details'] ?? '', style: TextStyle(color: Colors.grey[800])),
                        const SizedBox(height: 12),
                        const Text('Workers', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: (log['worker'] ?? '')
                              .toString()
                              .split(', ')
                              .where((s) => s.isNotEmpty)
                              .map<Widget>((w) => Chip(label: Text(w), backgroundColor: Colors.grey.shade100))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        if (logPhotos.isNotEmpty) ...[
                          const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 220,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: logPhotos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final xfile = logPhotos[i];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImagePreviewPage(xfile: xfile)));
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: FutureBuilder<Uint8List>(
                                      future: xfile.readAsBytes(),
                                      builder: (context, snap) {
                                        if (snap.connectionState != ConnectionState.done) {
                                          return SizedBox(width: 320, height: 220, child: Center(child: CircularProgressIndicator()));
                                        }
                                        if (snap.hasError || snap.data == null) {
                                          return SizedBox(width: 320, height: 220, child: Center(child: Icon(Icons.broken_image)));
                                        }
                                        return Image.memory(snap.data!, width: 320, height: 220, fit: BoxFit.cover);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ),
                // actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                      child: const Text('Done', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({super.key, required this.xfile});
  final XFile xfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: FutureBuilder<Uint8List>(
          future: xfile.readAsBytes(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const CircularProgressIndicator();
            if (snap.hasError || snap.data == null) return const Icon(Icons.broken_image, color: Colors.white);
            return InteractiveViewer(child: Image.memory(snap.data!, fit: BoxFit.contain));
          },
        ),
      ),
    );
  }
}
// filepath: c:\Users\Administrator\aestra_structura\flutter_app\lib\supervisor\daily_logs.dart