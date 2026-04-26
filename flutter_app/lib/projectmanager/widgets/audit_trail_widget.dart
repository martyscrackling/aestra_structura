import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/pm_dashboard_service.dart';

class AuditTrailWidget extends StatefulWidget {
  const AuditTrailWidget({super.key});

  @override
  State<AuditTrailWidget> createState() => _AuditTrailWidgetState();
}

class _AuditTrailWidgetState extends State<AuditTrailWidget> {
  final PmDashboardService _service = PmDashboardService();

  bool _isLoading = true;
  String? _error;
  List<PmAuditTrailEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadAuditTrail();
  }

  Future<void> _loadAuditTrail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = AuthService();
      final userIdRaw = authService.currentUser?['user_id'];
      final userId = userIdRaw is int
          ? userIdRaw
          : int.tryParse(userIdRaw?.toString() ?? '');
      if (userId == null) {
        throw Exception('Missing user id');
      }

      final entries = await _service.fetchAuditTrail(userId: userId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(DateTime? ts) {
    if (ts == null) return '—';
    final local = ts.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inSeconds < 60 && diff.inSeconds >= 0) {
      return 'Just now';
    }
    if (diff.inMinutes < 60 && diff.inMinutes >= 0) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24 && diff.inHours >= 0) {
      return '${diff.inHours}h ago';
    }

    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $hh:$mm';
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'project':
        return const Color(0xFF1976D2);
      case 'phase':
        return const Color(0xFF7B1FA2);
      case 'task':
        return const Color(0xFFFF6F00);
      case 'assignment':
        return const Color(0xFF00838F);
      case 'worker':
        return const Color(0xFF2E7D32);
      case 'supervisor':
        return const Color(0xFF6D4C41);
      case 'client':
        return const Color(0xFFC2185B);
      case 'inventory':
        return const Color(0xFF5E35B1);
      case 'attendance':
        return const Color(0xFF00796B);
      default:
        return const Color(0xFF546E7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 375;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    final padding = isSmallPhone
        ? 12.0
        : isMobile
        ? 16.0
        : 20.0;

    final titleSize = isSmallPhone
        ? 14.0
        : isMobile
        ? 16.0
        : isTablet
        ? 17.0
        : 18.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audit Trail',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recent activity across your organization',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadAuditTrail,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh',
                color: const Color(0xFF0C1935),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => context.push('/audit-trail'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0C1935),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text(
                  'See More',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTable(isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildTable({required bool isMobile}) {
    if (_isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 32),
              const SizedBox(height: 8),
              Text(
                'Failed to load audit trail.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadAuditTrail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C1935),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: Colors.grey[400], size: 32),
            const SizedBox(height: 8),
            Text(
              'No recent activity yet.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Column flex weights — keep responsive within the card, no horizontal scroll.
    final userFlex = isMobile ? 3 : 3;
    final actionFlex = isMobile ? 4 : 5;
    final timeFlex = isMobile ? 2 : 2;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeaderRow(
            userFlex: userFlex,
            actionFlex: actionFlex,
            timeFlex: timeFlex,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _entries.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF0F1F4)),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return _buildDataRow(
                    entry: entry,
                    userFlex: userFlex,
                    actionFlex: actionFlex,
                    timeFlex: timeFlex,
                    isAlternate: index.isOdd,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow({
    required int userFlex,
    required int actionFlex,
    required int timeFlex,
  }) {
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF0C1935),
      letterSpacing: 0.3,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FB),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: userFlex, child: const Text('USER', style: headerStyle)),
          const SizedBox(width: 8),
          Expanded(
            flex: actionFlex,
            child: const Text('ACTION / EVENT', style: headerStyle),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: timeFlex,
            child: const Text(
              'TIMESTAMP',
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow({
    required PmAuditTrailEntry entry,
    required int userFlex,
    required int actionFlex,
    required int timeFlex,
    required bool isAlternate,
  }) {
    final categoryColor = _categoryColor(entry.category);
    final initials = entry.userName.isNotEmpty
        ? entry.userName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: isAlternate ? const Color(0xFFFAFBFC) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: userFlex,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: categoryColor.withOpacity(0.15),
                  backgroundImage: entry.userProfileImage != null
                      ? NetworkImage(entry.userProfileImage!)
                      : null,
                  child: entry.userProfileImage != null
                      ? null
                      : Text(
                          initials,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: categoryColor,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.userName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      Text(
                        entry.userRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: actionFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: categoryColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.action,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0C1935),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: timeFlex,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatTimestamp(entry.timestamp),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
