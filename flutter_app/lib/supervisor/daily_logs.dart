import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import 'widgets/sidebar.dart';

class DailyLogsPage extends StatefulWidget {
  final bool initialSidebarVisible;

  const DailyLogsPage({super.key, this.initialSidebarVisible = false});

  @override
  State<DailyLogsPage> createState() => _DailyLogsPageState();
}

class _DailyLogsPageState extends State<DailyLogsPage> {
  final Color primary = const Color(0xFFFF6F00);
  final Color neutral = const Color(0xFFF4F6F9);
  final Color darkAction = const Color(0xFF0C1935);

  @override
  void initState() {
    super.initState();
  }

  void _navigateToPage(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Logs':
      case 'Daily Logs':
        return; // Already on logs page
      case 'Tasks':
      case 'Task Progress':
        context.go('/supervisor/task-progress');
        break;
      case 'Reports':
        context.go('/supervisor/reports');
        break;
      case 'Inventory':
        context.go('/supervisor/inventory');
        break;
      default:
        return;
    }
  }

  // Example workers — replace with your real source if available
  final List<String> allWorkers = [
    'John Doe',
    'Jane Smith',
    'Carlos Reyes',
    'Alice Brown',
  ];

  // store logs with status ('Draft' or 'Submitted')
  List<Map<String, dynamic>> logs = [];

  final ImagePicker _picker = ImagePicker();

  // Take photo using camera
  Future<XFile?> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      return photo;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to access camera')));
      return null;
    }
  }

  String _timeNow() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  bool hasNotifications = true;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final isMobile = width <= 600;

    return Scaffold(
      backgroundColor: neutral,
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop)
                Sidebar(
                  activePage: "Daily Logs",
                  keepVisible: true,
                ),
              Expanded(
                child: Column(
                  children: [
                    // Clean header
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 24,
                        vertical: isMobile ? 12 : 16,
                      ),
                      child: Row(
                        children: [
                          // Orange accent bar
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Title section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Daily Logs',
                                  style: TextStyle(
                                    color: darkAction,
                                    fontSize: isMobile ? 18 : 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (!isMobile) const SizedBox(height: 4),
                                if (!isMobile)
                                  Text(
                                    '${logs.length} logs • ${logs.where((l) => l['status'] == 'Draft').length} drafts • ${logs.where((l) => l['status'] == 'Submitted').length} submitted',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Notification icon
                          IconButton(
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.notifications_outlined,
                                  color: darkAction,
                                  size: 24,
                                ),
                                if (hasNotifications)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: () {
                              setState(() => hasNotifications = false);
                            },
                          ),

                        ],
                      ),
                    ),

                    // Main content: logs list
                    Expanded(
                      child: _buildLogsPanel(isMobile),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // Bottom navigation bar for mobile only
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
      // Floating action button for Add Log
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLogDialog,
        backgroundColor: primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Log',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonLocation: isMobile
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1935),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', false),
                _buildNavItem(Icons.people, 'Workers', false),
                _buildNavItem(Icons.check_circle, 'Attendance', false),
                _buildNavItem(Icons.list_alt, 'Logs', true),
                _buildNavItem(Icons.more_horiz, 'More', false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? const Color(0xFFFF6F00) : Colors.white70;

    return InkWell(
      onTap: () {
        if (label == 'More') {
          _showMoreOptions();
        } else {
          _navigateToPage(label);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF6F00).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C1935),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildMoreOption(Icons.show_chart, 'Task Progress', 'Tasks'),
              _buildMoreOption(Icons.file_copy, 'Reports', 'Reports'),
              _buildMoreOption(Icons.inventory, 'Inventory', 'Inventory'),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOption(IconData icon, String title, String page) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _navigateToPage(page);
      },
    );
  }

  Widget _buildLogsPanel(bool isMobile) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 20),
      child: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No logs yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add your first log',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: logs.length,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: isMobile ? 80 : 0),
              itemBuilder: (context, i) {
                final log = logs[i];
                final isDraft = (log['status'] ?? '') == 'Draft';
                
                return Container(
                  margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => _showLogDetails(log),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            children: [
                              // Status indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDraft
                                      ? Colors.orange.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isDraft ? Icons.edit : Icons.check_circle,
                                      size: 14,
                                      color: isDraft
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      log['status'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: isDraft
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Time
                              Text(
                                log['time'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              // Menu button
                              if (!isMobile)
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, size: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'edit' && isDraft) {
                                      _editDraft(i);
                                    } else if (value == 'view') {
                                      _showLogDetails(log);
                                    } else if (value == 'submit' && isDraft) {
                                      _submitDraft(i);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (isDraft)
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18),
                                            SizedBox(width: 12),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.visibility, size: 18),
                                          SizedBox(width: 12),
                                          Text('View Details'),
                                        ],
                                      ),
                                    ),
                                    if (isDraft)
                                      const PopupMenuItem(
                                        value: 'submit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.send, size: 18),
                                            SizedBox(width: 12),
                                            Text('Submit'),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Task title
                          Text(
                            log['task'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isMobile ? 15 : 16,
                              color: darkAction,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Workers
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  log['worker'] ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          // Mobile action buttons
                          if (isMobile && isDraft) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _editDraft(i),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _submitDraft(i),
                                    icon: const Icon(
                                      Icons.send,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Submit',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // Show Add Log Dialog
  void _showAddLogDialog() {
    final formKey = GlobalKey<FormState>();
    final taskController = TextEditingController();
    final detailsController = TextEditingController();
    List<String> selectedWorkers = [];
    List<XFile> photos = [];
    bool isDraft = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, primary.withOpacity(0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_task,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Log',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Record daily work activities',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Title',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: taskController,
                            decoration: InputDecoration(
                              hintText: 'E.g., Concrete pouring',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter log title'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: detailsController,
                            decoration: InputDecoration(
                              hintText:
                                  'Describe the work done, materials used, issues encountered...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            maxLines: 4,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter details'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Workers',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${selectedWorkers.length} selected',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final List<String>? picked =
                                  await showDialog<List<String>>(
                                    context: context,
                                    builder: (context) {
                                      final tempSelected = List<String>.from(
                                        selectedWorkers,
                                      );
                                      return AlertDialog(
                                        title: const Text('Select Workers'),
                                        content: StatefulBuilder(
                                          builder: (context, setDialogState) {
                                            return SizedBox(
                                              width: 320,
                                              child: ListView(
                                                shrinkWrap: true,
                                                children: allWorkers.map((w) {
                                                  final isSel = tempSelected
                                                      .contains(w);
                                                  return CheckboxListTile(
                                                    value: isSel,
                                                    title: Text(w),
                                                    controlAffinity:
                                                        ListTileControlAffinity
                                                            .leading,
                                                    onChanged: (v) {
                                                      setDialogState(() {
                                                        if (v == true) {
                                                          tempSelected.add(w);
                                                        } else {
                                                          tempSelected.remove(
                                                            w,
                                                          );
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
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, null),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              tempSelected,
                                            ),
                                            child: const Text('Done'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                              if (picked != null) {
                                setState(() => selectedWorkers = picked);
                              }
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Select Workers'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: BorderSide(color: primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          if (selectedWorkers.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: selectedWorkers
                                  .map(
                                    (w) => Chip(
                                      label: Text(
                                        w,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onDeleted: () => setState(
                                        () => selectedWorkers.remove(w),
                                      ),
                                      deleteIconColor: Colors.grey[600],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Photos',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${photos.length} photos',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final photo = await _takePhoto();
                              if (photo != null) {
                                setState(() => photos.add(photo));
                              }
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: BorderSide(color: primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          if (photos.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: photos.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: FutureBuilder<Uint8List>(
                                          future: photos[i].readAsBytes(),
                                          builder: (context, snap) {
                                            if (snap.connectionState !=
                                                ConnectionState.done) {
                                              return const SizedBox(
                                                width: 100,
                                                height: 100,
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            }
                                            if (snap.hasError ||
                                                snap.data == null) {
                                              return const SizedBox(
                                                width: 100,
                                                height: 100,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                  ),
                                                ),
                                              );
                                            }
                                            return Image.memory(
                                              snap.data!,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            );
                                          },
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () => photos.removeAt(i),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              if (selectedWorkers.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Select at least one worker'),
                                  ),
                                );
                                return;
                              }
                              final entry = {
                                'time': _timeNow(),
                                'worker': selectedWorkers.join(', '),
                                'task': taskController.text.trim(),
                                'details': detailsController.text.trim(),
                                'photos': List<XFile>.from(photos),
                                'status': 'Draft',
                              };
                              this.setState(() => logs.insert(0, entry));
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Draft saved')),
                              );
                            }
                          },
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Save Draft'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              if (selectedWorkers.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Select at least one worker'),
                                  ),
                                );
                                return;
                              }
                              final entry = {
                                'time': _timeNow(),
                                'worker': selectedWorkers.join(', '),
                                'task': taskController.text.trim(),
                                'details': detailsController.text.trim(),
                                'photos': List<XFile>.from(photos),
                                'status': 'Submitted',
                              };
                              this.setState(() => logs.insert(0, entry));
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Submitted to PM'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.send,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Submit',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // helper: load draft into form for editing
  void _editDraft(int index) {
    final log = logs[index];
    final taskText = log['task'] ?? '';
    final detailsText = log['details'] ?? '';
    final workers = List<String>.from(
      ((log['worker'] ?? '') as String).split(', ').where((s) => s.isNotEmpty),
    );
    final logPhotos = List<XFile>.from(log['photos'] ?? []);

    // Remove the log from the list
    setState(() {
      logs.removeAt(index);
    });

    // Open the add dialog with pre-filled data
    _showAddLogDialogWithData(taskText, detailsText, workers, logPhotos);
  }

  // Show Add Log Dialog with pre-filled data (for editing drafts)
  void _showAddLogDialogWithData(
    String initialTask,
    String initialDetails,
    List<String> initialWorkers,
    List<XFile> initialPhotos,
  ) {
    final formKey = GlobalKey<FormState>();
    final taskController = TextEditingController(text: initialTask);
    final detailsController = TextEditingController(text: initialDetails);
    List<String> selectedWorkers = List.from(initialWorkers);
    List<XFile> photos = List.from(initialPhotos);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, primary.withOpacity(0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Log',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Update work activity details',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Title',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: taskController,
                            decoration: InputDecoration(
                              hintText: 'E.g., Concrete pouring',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter log title'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: detailsController,
                            decoration: InputDecoration(
                              hintText:
                                  'Describe the work done, materials used, issues encountered...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            maxLines: 4,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter details'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Workers',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${selectedWorkers.length} selected',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final List<String>? picked =
                                  await showDialog<List<String>>(
                                    context: context,
                                    builder: (context) {
                                      final tempSelected = List<String>.from(
                                        selectedWorkers,
                                      );
                                      return AlertDialog(
                                        title: const Text('Select Workers'),
                                        content: StatefulBuilder(
                                          builder: (context, setDialogState) {
                                            return SizedBox(
                                              width: 320,
                                              child: ListView(
                                                shrinkWrap: true,
                                                children: allWorkers.map((w) {
                                                  final isSel = tempSelected
                                                      .contains(w);
                                                  return CheckboxListTile(
                                                    value: isSel,
                                                    title: Text(w),
                                                    controlAffinity:
                                                        ListTileControlAffinity
                                                            .leading,
                                                    onChanged: (v) {
                                                      setDialogState(() {
                                                        if (v == true) {
                                                          tempSelected.add(w);
                                                        } else {
                                                          tempSelected.remove(
                                                            w,
                                                          );
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
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, null),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              tempSelected,
                                            ),
                                            child: const Text('Done'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                              if (picked != null) {
                                setState(() => selectedWorkers = picked);
                              }
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Select Workers'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: BorderSide(color: primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          if (selectedWorkers.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: selectedWorkers
                                  .map(
                                    (w) => Chip(
                                      label: Text(
                                        w,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onDeleted: () => setState(
                                        () => selectedWorkers.remove(w),
                                      ),
                                      deleteIconColor: Colors.grey[600],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Photos',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${photos.length} photos',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final photo = await _takePhoto();
                              if (photo != null) {
                                setState(() => photos.add(photo));
                              }
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: BorderSide(color: primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          if (photos.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: photos.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: FutureBuilder<Uint8List>(
                                          future: photos[i].readAsBytes(),
                                          builder: (context, snap) {
                                            if (snap.connectionState !=
                                                ConnectionState.done) {
                                              return const SizedBox(
                                                width: 100,
                                                height: 100,
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            }
                                            if (snap.hasError ||
                                                snap.data == null) {
                                              return const SizedBox(
                                                width: 100,
                                                height: 100,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                  ),
                                                ),
                                              );
                                            }
                                            return Image.memory(
                                              snap.data!,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            );
                                          },
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () => photos.removeAt(i),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              if (selectedWorkers.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Select at least one worker'),
                                  ),
                                );
                                return;
                              }
                              final entry = {
                                'time': _timeNow(),
                                'worker': selectedWorkers.join(', '),
                                'task': taskController.text.trim(),
                                'details': detailsController.text.trim(),
                                'photos': List<XFile>.from(photos),
                                'status': 'Draft',
                              };
                              this.setState(() => logs.insert(0, entry));
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Draft saved')),
                              );
                            }
                          },
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Save Draft'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              if (selectedWorkers.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Select at least one worker'),
                                  ),
                                );
                                return;
                              }
                              final entry = {
                                'time': _timeNow(),
                                'worker': selectedWorkers.join(', '),
                                'task': taskController.text.trim(),
                                'details': detailsController.text.trim(),
                                'photos': List<XFile>.from(photos),
                                'status': 'Submitted',
                              };
                              this.setState(() => logs.insert(0, entry));
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Updated and submitted'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.send,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Submit',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // helper: mark a draft as submitted
  void _submitDraft(int index) {
    setState(() {
      logs[index]['status'] = 'Submitted';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft submitted')));
  }

  // Open log (centered modal)
  void _showLogDetails(Map<String, dynamic> log) {
    final List<XFile> logPhotos = List<XFile>.from(log['photos'] ?? []);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 24.0,
        ),
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
                      child: Text(
                        log['task'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: (log['status'] == 'Submitted')
                                    ? Colors.green.withOpacity(0.12)
                                    : Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                log['status'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: (log['status'] == 'Submitted')
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              log['time'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Details',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          log['details'] ?? '',
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Workers',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: (log['worker'] ?? '')
                              .toString()
                              .split(', ')
                              .where((s) => s.isNotEmpty)
                              .map<Widget>(
                                (w) => Chip(
                                  label: Text(w),
                                  backgroundColor: Colors.grey.shade100,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        if (logPhotos.isNotEmpty) ...[
                          const Text(
                            'Photos',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 220,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: logPhotos.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final xfile = logPhotos[i];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ImagePreviewPage(xfile: xfile),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: FutureBuilder<Uint8List>(
                                      future: xfile.readAsBytes(),
                                      builder: (context, snap) {
                                        if (snap.connectionState !=
                                            ConnectionState.done) {
                                          return SizedBox(
                                            width: 320,
                                            height: 220,
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        }
                                        if (snap.hasError ||
                                            snap.data == null) {
                                          return SizedBox(
                                            width: 320,
                                            height: 220,
                                            child: Center(
                                              child: Icon(Icons.broken_image),
                                            ),
                                          );
                                        }
                                        return Image.memory(
                                          snap.data!,
                                          width: 320,
                                          height: 220,
                                          fit: BoxFit.cover,
                                        );
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
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                      child: const Text(
                        'Done',
                        style: TextStyle(color: Colors.white),
                      ),
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
            if (snap.connectionState != ConnectionState.done)
              return const CircularProgressIndicator();
            if (snap.hasError || snap.data == null)
              return const Icon(Icons.broken_image, color: Colors.white);
            return InteractiveViewer(
              child: Image.memory(snap.data!, fit: BoxFit.contain),
            );
          },
        ),
      ),
    );
  }
}
// filepath: c:\Users\Administrator\aestra_structura\flutter_app\lib\supervisor\daily_logs.dart