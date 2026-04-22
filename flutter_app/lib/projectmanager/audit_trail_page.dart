import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/pm_dashboard_service.dart';
import 'widgets/responsive_page_layout.dart';

class AuditTrailPage extends StatefulWidget {
  const AuditTrailPage({super.key});

  @override
  State<AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<AuditTrailPage> {
  final PmDashboardService _service = PmDashboardService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<PmAuditTrailEntry> _entries = const [];
  String _selectedModule = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      final value = _searchController.text.trim();
      if (value != _searchQuery) {
        setState(() {
          _searchQuery = value;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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

      final entries = await _service.fetchAuditTrail(
        userId: userId,
        limit: 500,
      );
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

  List<String> get _availableModules {
    final set = <String>{};
    for (final e in _entries) {
      if (e.module.trim().isNotEmpty) set.add(e.module);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<PmAuditTrailEntry> get _filteredEntries {
    final query = _searchQuery.toLowerCase();
    return _entries.where((e) {
      if (_selectedModule != 'All' && e.module != _selectedModule) return false;
      if (query.isEmpty) return true;
      return e.userName.toLowerCase().contains(query) ||
          e.action.toLowerCase().contains(query) ||
          e.affectedRecord.toLowerCase().contains(query) ||
          e.module.toLowerCase().contains(query) ||
          e.statusResult.toLowerCase().contains(query);
    }).toList();
  }

  String _formatTimestamp(DateTime? ts) {
    if (ts == null) return '—';
    final local = ts.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $hh:$mm:$ss';
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

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'success' || s == 'completed') return const Color(0xFF2E7D32);
    if (s == 'failed' || s == 'error' || s == 'absent') {
      return const Color(0xFFC62828);
    }
    if (s == 'pending' || s == 'warning') return const Color(0xFFEF6C00);
    return const Color(0xFF546E7A);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePageLayout(
      currentPage: 'Dashboard',
      title: 'Audit Trail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBar(),
          const SizedBox(height: 16),
          _buildToolbar(),
          const SizedBox(height: 12),
          _buildTableCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFF0C1935),
          tooltip: 'Back',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Audit Trail',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0C1935),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Full activity log for your organization',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          color: const Color(0xFF0C1935),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final modules = _availableModules;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Search user, action, record...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF0C1935),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<String>(
              value: modules.contains(_selectedModule) ? _selectedModule : 'All',
              underline: const SizedBox.shrink(),
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              items: modules
                  .map(
                    (m) => DropdownMenuItem<String>(
                      value: m,
                      child: Text(
                        m == 'All' ? 'All modules' : m,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedModule = value;
                });
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_filteredEntries.length} of ${_entries.length} events',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0C1935),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard() {
    if (_isLoading) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 36, color: Colors.red[400]),
            const SizedBox(height: 8),
            Text(
              'Failed to load audit trail.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C1935),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final rows = _filteredEntries;
    if (rows.isEmpty) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: Colors.grey[400], size: 36),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty && _selectedModule == 'All'
                  ? 'No audit events recorded yet.'
                  : 'No events match your filters.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minTableWidth = 920.0;
          final availableWidth = constraints.maxWidth;
          final tableWidth =
              availableWidth < minTableWidth ? minTableWidth : availableWidth;

          final table = SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                _buildHeaderRow(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 620),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: Color(0xFFF0F1F4),
                      ),
                      itemBuilder: (context, index) {
                        return _buildDataRow(rows[index], index.isOdd);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );

          if (availableWidth < minTableWidth) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            );
          }
          return table;
        },
      ),
    );
  }

  // Column flex weights.
  static const int _userFlex = 3;
  static const int _actionFlex = 5;
  static const int _timeFlex = 3;
  static const int _affectedFlex = 4;
  static const int _moduleFlex = 2;
  static const int _statusFlex = 2;

  Widget _buildHeaderRow() {
    const style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: Color(0xFF0C1935),
      letterSpacing: 0.3,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: const [
          Expanded(flex: _userFlex, child: Text('USER', style: style)),
          SizedBox(width: 10),
          Expanded(flex: _actionFlex, child: Text('ACTION / EVENT', style: style)),
          SizedBox(width: 10),
          Expanded(flex: _timeFlex, child: Text('TIMESTAMP', style: style)),
          SizedBox(width: 10),
          Expanded(
            flex: _affectedFlex,
            child: Text('AFFECTED RECORD', style: style),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: _moduleFlex,
            child: Text('MODULE', style: style),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: _statusFlex,
            child: Text(
              'STATUS',
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(PmAuditTrailEntry entry, bool isAlternate) {
    final categoryColor = _categoryColor(entry.category);
    final statusColor = _statusColor(entry.statusResult);
    final initials = entry.userName.isNotEmpty
        ? entry.userName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      color: isAlternate ? const Color(0xFFFAFBFC) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: _userFlex,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: categoryColor.withOpacity(0.15),
                  child: Text(
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
          const SizedBox(width: 10),
          Expanded(
            flex: _actionFlex,
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
          const SizedBox(width: 10),
          Expanded(
            flex: _timeFlex,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatTimestamp(entry.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: _affectedFlex,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                entry.affectedRecord,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF0C1935),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: _moduleFlex,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                entry.module,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1935),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: _statusFlex,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  entry.statusResult,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
