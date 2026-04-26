import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/responsive_page_layout.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/file_download/file_download.dart';

class AttendanceReport {
  AttendanceReport({
    required this.name,
    required this.role,
    required this.totalDaysPresent,
    required this.totalHours,
    required this.overtimeHours,
    required this.cashAdvance,
    required this.deduction,
    required this.hourlyRate,
  });

  final String name;
  final String role;
  final int totalDaysPresent;
  final double totalHours;
  final double overtimeHours;
  final double cashAdvance;
  final double deduction;
  final double hourlyRate;

  double get grossPay =>
      totalHours * hourlyRate + overtimeHours * hourlyRate * 1.5;
  double get computedSalary => (grossPay - cashAdvance - deduction);
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

/// Total deductions (aligned with the salary table and supervisor payload).
double reportWorkerTotalDeductions(Map<String, dynamic> w) {
  if (w.containsKey('total_deductions')) {
    return _parseDouble(w['total_deductions']);
  }
  final g = _parseDouble(w['gross_pay']);
  final c = _parseDouble(w['computed_salary']);
  if (g != 0.0 || c != 0.0) {
    return (g - c).abs();
  }
  return _parseDouble(w['deduction']) +
      _parseDouble(w['damages_deduction']) +
      _parseDouble(w['sss_deduction']) +
      _parseDouble(w['philhealth_deduction']) +
      _parseDouble(w['pagibig_deduction']);
}

String _csvEsc(String? v) {
  final s = v ?? '';
  if (s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Excel-friendly UTF-8 CSV with header rows + one line per worker.
String buildSupervisorReportCsv(Map<String, dynamic> report) {
  final sb = StringBuffer();
  final sid = (report['submission_id'] ?? '').toString();
  final sup = (report['supervisor_name'] ?? '').toString();
  final project = (report['project_name'] ?? '').toString();
  final submitted = (report['submitted_at'] ?? '').toString();
  final salaryDate = (report['salary_date'] ?? '').toString();
  final start = (report['report_start'] ?? '').toString();
  final end = (report['report_end'] ?? '').toString();

  sb.writeln('Field,Value');
  sb.writeln('Submission ID,${_csvEsc(sid)}');
  sb.writeln('Supervisor,${_csvEsc(sup)}');
  sb.writeln('Project,${_csvEsc(project)}');
  sb.writeln('Submitted at,${_csvEsc(submitted)}');
  if (salaryDate.isNotEmpty) {
    sb.writeln('Salary date,${_csvEsc(salaryDate)}');
  }
  sb.writeln('Report start,${_csvEsc(start)}');
  sb.writeln('Report end,${_csvEsc(end)}');

  final totals = report['totals'] is Map
      ? Map<String, dynamic>.from(report['totals'] as Map)
      : <String, dynamic>{};
  sb.writeln('Total hours (summary),${totals['total_hours'] ?? ''}');
  sb.writeln('Total OT (summary),${totals['total_ot'] ?? ''}');
  sb.writeln('Total deductions (summary),${totals['total_deductions'] ?? ''}');
  sb.writeln('Total computed salary (summary),${totals['total_salary'] ?? ''}');
  final budgetSummary = report['project_budget_summary'] is Map
      ? Map<String, dynamic>.from(report['project_budget_summary'] as Map)
      : <String, dynamic>{};
  if (budgetSummary.isNotEmpty) {
    sb.writeln('Project total budget,${budgetSummary['total_budget'] ?? ''}');
    sb.writeln(
      'Project used materials,${budgetSummary['total_used_materials'] ?? ''}',
    );
    sb.writeln('Project used payroll,${budgetSummary['total_used_payroll'] ?? ''}');
    sb.writeln('Project remaining budget,${budgetSummary['remaining_budget'] ?? ''}');
  }
  sb.writeln();
  sb.writeln(
    'Name,Role,Days,Hours,OT hours,Hourly rate,Gross pay,Total deductions,Cash advance,Computed salary (net)',
  );
  final workers = (report['workers'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((w) => Map<String, dynamic>.from(w));
  for (final m in workers) {
    final ded = reportWorkerTotalDeductions(m);
    sb.writeln(
      [
        _csvEsc(m['name']?.toString()),
        _csvEsc(m['role']?.toString()),
        m['day'] ?? '',
        m['hours'] ?? '',
        m['ot_hours'] ?? '',
        m['hourly_rate'] ?? '',
        m['gross_pay'] ?? '',
        ded.toStringAsFixed(2),
        m['cash_advance'] ?? '',
        m['computed_salary'] ?? '',
      ].join(','),
    );
  }
  return '\uFEFF$sb';
}

String reportExportFilename(Map<String, dynamic> report) {
  var base = (report['submission_id'] ?? '').toString();
  if (base.isEmpty) {
    final pid = report['project_id']?.toString() ?? 'project';
    final t = (report['submitted_at'] ?? DateTime.now().toIso8601String())
        .toString();
    base = '${pid}_$t';
  }
  final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  if (safe.isEmpty) return 'supervisor_report.csv';
  return '$safe.csv';
}

Future<void> exportSupervisorReportCsv(
  BuildContext context,
  Map<String, dynamic> report,
) async {
  final csv = buildSupervisorReportCsv(report);
  final bytes = Uint8List.fromList(utf8.encode(csv));
  final name = reportExportFilename(report);
  try {
    await downloadBytes(
      bytes: bytes,
      filename: name,
      mimeType: 'text/csv; charset=utf-8',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported: $name')),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

class ReportsPage extends StatefulWidget {
  ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Color neutral = const Color(0xFFF4F6F9);
  final Color accent = const Color(0xFFFF7A18);
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final TextEditingController _searchController = TextEditingController();

  DateTime _weekStart = DateTime.now();
  DateTime _weekEnd = DateTime.now();
  List<Map<String, dynamic>> _submittedReports = [];
  int _selectedReportIndex = -1;
  String _searchQuery = '';

  // sample data (UI/layout only - no backend)
  List<AttendanceReport> _rows = [
    AttendanceReport(
      name: 'John Doe',
      role: 'Foreman',
      totalDaysPresent: 6,
      totalHours: 48,
      overtimeHours: 4,
      cashAdvance: 50.0,
      deduction: 0.0,
      hourlyRate: 8.0,
    ),
    AttendanceReport(
      name: 'Jane Smith',
      role: 'Carpenter',
      totalDaysPresent: 5,
      totalHours: 40,
      overtimeHours: 2,
      cashAdvance: 0.0,
      deduction: 10.0,
      hourlyRate: 7.5,
    ),
    AttendanceReport(
      name: 'Carlos Reyes',
      role: 'Laborer',
      totalDaysPresent: 6,
      totalHours: 52,
      overtimeHours: 6,
      cashAdvance: 20.0,
      deduction: 5.0,
      hourlyRate: 6.0,
    ),
  ];

  final _money = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadSubmittedSupervisorReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _readText(
    Map<String, dynamic> map,
    List<String> keys,
    String fallback,
  ) {
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      final text = v.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  DateTime? _parseSubmittedAt(Map<String, dynamic> map) {
    final raw = (map['submitted_at'] ?? '').toString();
    return DateTime.tryParse(raw);
  }

  bool _isMissingOrPlaceholderSupervisorName(String name) {
    final n = name.trim().toLowerCase();
    return n.isEmpty ||
        n == 'supervisor' ||
        n == 'unknown supervisor' ||
        n == 'unknown';
  }

  bool _isMissingOrPlaceholderProjectName(String name) {
    final n = name.trim().toLowerCase();
    return n.isEmpty ||
        n == 'project' ||
        n == 'unknown project' ||
        n == 'unknown' ||
        RegExp(r'^project\s*#?\s*\d+$', caseSensitive: false).hasMatch(n);
  }

  int? _getCurrentUserIdFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString('current_user');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        return _toInt(map['user_id']) ?? _toInt(map['id']);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<int, String>> _fetchProjectNameLookup(int userId) async {
    final response = await http.get(
      AppConfig.apiUri('projects/?user_id=$userId'),
    );
    if (response.statusCode != 200) return {};

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return {};

    final map = <int, String>{};
    for (final item in decoded) {
      if (item is! Map) continue;
      final project = Map<String, dynamic>.from(item);
      final projectId = _toInt(project['project_id']) ?? _toInt(project['id']);
      final projectName = _readText(project, const [
        'project_name',
        'name',
        'title',
      ], '');
      if (projectId != null && projectName.isNotEmpty) {
        map[projectId] = projectName;
      }
    }
    return map;
  }

  Future<Map<int, String>> _fetchSupervisorNameLookup(int userId) async {
    final response = await http.get(
      AppConfig.apiUri('supervisors/?user_id=$userId'),
    );
    if (response.statusCode != 200) return {};

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return {};

    final map = <int, String>{};
    for (final item in decoded) {
      if (item is! Map) continue;
      final supervisor = Map<String, dynamic>.from(item);
      final supervisorId =
          _toInt(supervisor['supervisor_id']) ?? _toInt(supervisor['id']);
      final firstName = (supervisor['first_name'] ?? '').toString().trim();
      final lastName = (supervisor['last_name'] ?? '').toString().trim();
      final fullName = [
        firstName,
        lastName,
      ].where((part) => part.isNotEmpty).join(' ').trim();
      final fallbackName = _readText(supervisor, const [
        'full_name',
        'name',
        'username',
        'email',
      ], '');
      final resolvedName = fullName.isNotEmpty ? fullName : fallbackName;
      if (supervisorId != null && resolvedName.isNotEmpty) {
        map[supervisorId] = resolvedName;
      }
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> _enrichReportsWithRealNames(
    List<Map<String, dynamic>> reports,
    SharedPreferences prefs,
  ) async {
    final userId = _getCurrentUserIdFromPrefs(prefs);
    if (userId == null) return reports;

    Map<int, String> projectById = const {};
    Map<int, String> supervisorById = const {};

    final projectFuture = _fetchProjectNameLookup(userId);
    final supervisorFuture = _fetchSupervisorNameLookup(userId);
    try {
      projectById = await projectFuture;
    } catch (_) {
      projectById = const {};
    }
    try {
      supervisorById = await supervisorFuture;
    } catch (_) {
      supervisorById = const {};
    }

    if (projectById.isEmpty && supervisorById.isEmpty) return reports;

    return reports.map((report) {
      final enriched = Map<String, dynamic>.from(report);

      final currentProjectName = _readText(enriched, const [
        'project_name',
      ], '');
      final projectId = _toInt(enriched['project_id']);
      final lookupProjectName = projectId == null
          ? null
          : projectById[projectId];
      if (lookupProjectName != null &&
          _isMissingOrPlaceholderProjectName(currentProjectName)) {
        enriched['project_name'] = lookupProjectName;
      }

      final currentSupervisorName = _readText(enriched, const [
        'supervisor_name',
      ], '');
      final supervisorId = _toInt(enriched['supervisor_id']);
      final lookupSupervisorName = supervisorId == null
          ? null
          : supervisorById[supervisorId];
      if (lookupSupervisorName != null &&
          _isMissingOrPlaceholderSupervisorName(currentSupervisorName)) {
        enriched['supervisor_name'] = lookupSupervisorName;
      }

      return enriched;
    }).toList();
  }

  String _reportStorageKey(Map<String, dynamic> report) {
    final submissionId = (report['submission_id'] ?? '').toString();
    final submittedAt = (report['submitted_at'] ?? '').toString();
    if (submissionId.isNotEmpty || submittedAt.isNotEmpty) {
      return '$submissionId|$submittedAt';
    }

    final projectId = (report['project_id'] ?? '').toString();
    final supervisorName = (report['supervisor_name'] ?? '')
        .toString()
        .toLowerCase();
    final reportStart = (report['report_start'] ?? '').toString();
    final reportEnd = (report['report_end'] ?? '').toString();
    return '$projectId|$supervisorName|$reportStart|$reportEnd';
  }

  Future<void> _deleteSubmission(Map<String, dynamic> report) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Submitted Report'),
        content: const Text(
          'Are you sure you want to delete this submitted report?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _getCurrentUserIdFromPrefs(prefs) ??
          _toInt(AuthService().currentUser?['user_id']);
      final serverId = _toInt(report['id']);

      if (userId != null && serverId != null) {
        final res = await http.delete(
          AppConfig.apiUri(
            'supervisor-reports/$serverId/?user_id=$userId',
          ),
        );
        if (res.statusCode != 204 && res.statusCode != 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Server delete failed (${res.statusCode}).',
              ),
            ),
          );
          return;
        }
      }

      final targetKey = _reportStorageKey(report);

      final latestRaw = prefs.getString('pm_latest_report_v1');
      if (latestRaw != null && latestRaw.isNotEmpty) {
        final decodedLatest = jsonDecode(latestRaw);
        if (decodedLatest is Map) {
          final latestMap = Map<String, dynamic>.from(decodedLatest);
          if (_reportStorageKey(latestMap) == targetKey) {
            await prefs.remove('pm_latest_report_v1');
          }
        }
      }

      final listRaw = prefs.getString('supervisor_submitted_reports_v1');
      final decodedList = (listRaw == null || listRaw.isEmpty)
          ? const []
          : jsonDecode(listRaw);
      if (decodedList is List) {
        final updated = decodedList
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => _reportStorageKey(item) != targetKey)
            .toList();
        await prefs.setString(
          'supervisor_submitted_reports_v1',
          jsonEncode(updated),
        );
      }

      await _loadSubmittedSupervisorReports();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted report deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete report.')));
    }
  }

  String _formatSubmittedDate(Map<String, dynamic> report) {
    final submittedAt = _parseSubmittedAt(report);
    if (submittedAt == null) return 'Unknown';
    return DateFormat('MMM d, yyyy').format(submittedAt);
  }

  String _formatSubmittedTime(Map<String, dynamic> report) {
    final submittedAt = _parseSubmittedAt(report);
    if (submittedAt == null) return 'Unknown';
    return DateFormat('h:mm a').format(submittedAt);
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _openSubmissionDetailsPage(Map<String, dynamic> report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubmissionDetailsPage(report: report),
      ),
    );
  }

  void _applySubmission(Map<String, dynamic> report) {
    final workerRows = (report['workers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((w) {
          final m = Map<String, dynamic>.from(w);
          return AttendanceReport(
            name: (m['name'] ?? 'Unknown').toString(),
            role: (m['role'] ?? 'Worker').toString(),
            totalDaysPresent: int.tryParse((m['day'] ?? '0').toString()) ?? 0,
            totalHours: double.tryParse((m['hours'] ?? '0').toString()) ?? 0,
            overtimeHours:
                double.tryParse((m['ot_hours'] ?? '0').toString()) ?? 0,
            cashAdvance:
                double.tryParse((m['cash_advance'] ?? '0').toString()) ?? 0,
            deduction: double.tryParse((m['deduction'] ?? '0').toString()) ?? 0,
            hourlyRate:
                double.tryParse((m['hourly_rate'] ?? '0').toString()) ?? 0,
          );
        })
        .toList();

    final start = DateTime.tryParse((report['report_start'] ?? '').toString());
    final end = DateTime.tryParse((report['report_end'] ?? '').toString());

    if (!mounted) return;
    setState(() {
      if (start != null) _weekStart = start;
      if (end != null) _weekEnd = end;
      _rows = workerRows;
    });
  }

  Future<void> _loadSubmittedSupervisorReports() async {
    final prefs = await SharedPreferences.getInstance();
    var userId = _getCurrentUserIdFromPrefs(prefs) ??
        _toInt(AuthService().currentUser?['user_id']);

    final collected = <Map<String, dynamic>>[];
    final seenSubmissionIds = <String>{};

    if (userId != null) {
      try {
        final response = await http.get(
          AppConfig.apiUri('supervisor-reports/?user_id=$userId'),
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                collected.add(m);
                final sid = '${m['submission_id'] ?? ''}';
                if (sid.isNotEmpty) seenSubmissionIds.add(sid);
              }
            }
          }
        }
      } catch (_) {
        // Fall through to local prefs
      }
    }

    void addLocalIfMissing(Map<String, dynamic> m) {
      final sid = '${m['submission_id'] ?? ''}';
      if (sid.isNotEmpty) {
        if (seenSubmissionIds.contains(sid)) return;
        seenSubmissionIds.add(sid);
      }
      collected.add(m);
    }

    final latestRaw = prefs.getString('pm_latest_report_v1');
    if (latestRaw != null && latestRaw.isNotEmpty) {
      final decodedLatest = jsonDecode(latestRaw);
      if (decodedLatest is Map) {
        addLocalIfMissing(Map<String, dynamic>.from(decodedLatest));
      }
    }

    final raw = prefs.getString('supervisor_submitted_reports_v1');
    final decoded = (raw == null || raw.isEmpty) ? const [] : jsonDecode(raw);
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          addLocalIfMissing(Map<String, dynamic>.from(item));
        }
      }
    }

    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final report in collected) {
      final key =
          '${report['submission_id'] ?? ''}|${report['submitted_at'] ?? ''}';
      if (seen.contains(key)) continue;
      seen.add(key);
      unique.add(report);
    }

    unique.sort((a, b) {
      final da = _parseSubmittedAt(a);
      final db = _parseSubmittedAt(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    try {
      final enriched = await _enrichReportsWithRealNames(unique, prefs);

      if (!mounted) return;
      setState(() {
        _submittedReports = enriched;
        _selectedReportIndex = enriched.isEmpty ? -1 : 0;
      });

      if (enriched.isNotEmpty) {
        _applySubmission(enriched.first);
      } else {
        setState(() {
          _rows = [];
        });
      }
    } catch (_) {
      // Keep existing sample data if loading fails.
    }
  }

  Widget _submissionCard({
    required Map<String, dynamic> report,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final projectId = _toInt(report['project_id']);
    final projectLabel = _readText(report, const [
      'project_name',
    ], projectId == null ? 'Unknown Project' : 'Project #$projectId');
    final supervisorLabel = _readText(report, const [
      'supervisor_name',
    ], 'Unknown Supervisor');
    final submittedAt = _parseSubmittedAt(report);
    final submittedText = submittedAt == null
        ? 'Unknown submit date'
        : DateFormat('MMM d, yyyy • h:mm a').format(submittedAt);
    final totalWorkers = (report['workers'] as List?)?.length ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3E8) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accent : const Color(0xFFE6E9EF),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.assignment_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    projectLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0C1935),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Supervisor: $supervisorLabel',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$submittedText • $totalWorkers workers',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.chevron_right,
              color: isSelected ? accent : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  double get _totalDeductions =>
      _rows.fold(0.0, (t, r) => t + r.deduction + r.cashAdvance);
  double get _totalComputedSalary =>
      _rows.fold(0.0, (t, r) => t + r.computedSalary);
  double get _totalOvertime => _rows.fold(0.0, (t, r) => t + r.overtimeHours);
  double get _totalHours => _rows.fold(0.0, (t, r) => t + r.totalHours);

  Future<void> _pickReportDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _weekStart = d;
        _weekEnd = d;
      });
    }
  }

  Widget _kpiCard(String title, String value, {Color? color, IconData? icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (icon != null)
              Container(
                decoration: BoxDecoration(
                  color: (color ?? accent).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color ?? accent, size: 20),
              ),
            if (icon != null) const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color ?? Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowCard(AttendanceReport r) {
    final initials = r.name
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join();
    final salaryStr = _money.format(r.computedSalary);
    final deductionStr = _money.format(r.deduction + r.cashAdvance);
    final cashAdvanceStr = _money.format(r.cashAdvance);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: accent.withOpacity(0.14),
              child: Text(
                initials,
                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r.role,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${r.totalDaysPresent} days',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${r.totalHours.toStringAsFixed(1)} hrs',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 12),
                      if (r.overtimeHours > 0)
                        Chip(
                          label: Text('+${r.overtimeHours} OT'),
                          backgroundColor: Colors.orange.withOpacity(0.12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // show cash advance balance above computed salary and deduction
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Advance',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  cashAdvanceStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  salaryStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deduct: $deductionStr',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittedReportsTable(
    bool isMobile,
    List<Map<String, dynamic>> reports,
  ) {
    final labelStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      color: Color(0xFF0C1935),
    );

    if (reports.isEmpty) {
      return SizedBox.expand(
        child: Center(
          child: Text(
            _submittedReports.isEmpty
                ? 'No supervisor submissions yet.'
                : 'No matching reports found.',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(Colors.white),
                  dataRowColor: const WidgetStatePropertyAll(Colors.white),
                  columnSpacing: isMobile ? 18 : 32,
                  headingTextStyle: labelStyle,
                  columns: const [
                    DataColumn(label: Text('Supervisor Name')),
                    DataColumn(label: Text('Project Name')),
                    DataColumn(label: Text('Date Submitted')),
                    DataColumn(label: Text('Time')),
                    DataColumn(label: Text('Check')),
                    DataColumn(label: Text('Delete')),
                  ],
                  rows: reports.map((report) {
                    final projectId = _toInt(report['project_id']);
                    final supervisorLabel = _readText(report, const [
                      'supervisor_name',
                    ], 'Unknown Supervisor');
                    final projectLabel = _readText(
                      report,
                      const ['project_name'],
                      projectId == null
                          ? 'Unknown Project'
                          : 'Project #$projectId',
                    );

                    return DataRow(
                      cells: [
                        DataCell(Text(supervisorLabel)),
                        DataCell(Text(projectLabel)),
                        DataCell(Text(_formatSubmittedDate(report))),
                        DataCell(Text(_formatSubmittedTime(report))),
                        DataCell(
                          TextButton(
                            onPressed: () {
                              final index = _submittedReports.indexOf(report);
                              setState(() {
                                _selectedReportIndex = index;
                              });
                              _applySubmission(report);
                              _openSubmissionDetailsPage(report);
                            },
                            child: const Text('Check'),
                          ),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: () => _deleteSubmission(report),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportsSearchField(bool isMobile) {
    return SizedBox(
      width: isMobile ? double.infinity : 220,
      height: 36,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search reports...',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 18),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFF0C1935), width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final filteredReports = _submittedReports.where((report) {
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.trim().toLowerCase();
      final supervisor = _readText(report, const [
        'supervisor_name',
      ], '').toLowerCase();
      final project = _readText(report, const [
        'project_name',
      ], '').toLowerCase();
      final submittedDate = _formatSubmittedDate(report).toLowerCase();
      final submittedTime = _formatSubmittedTime(report).toLowerCase();
      return supervisor.contains(query) ||
          project.contains(query) ||
          submittedDate.contains(query) ||
          submittedTime.contains(query);
    }).toList();
    final selectedReport =
        (_selectedReportIndex >= 0 &&
            _selectedReportIndex < _submittedReports.length)
        ? _submittedReports[_selectedReportIndex]
        : null;
    final selectedProjectId = selectedReport == null
        ? null
        : _toInt(selectedReport['project_id']);
    final selectedProjectLabel = selectedReport == null
        ? 'No selected report'
        : _readText(
            selectedReport,
            const ['project_name'],
            selectedProjectId == null
                ? 'Unknown Project'
                : 'Project #$selectedProjectId',
          );
    final selectedSupervisorLabel = selectedReport == null
        ? 'Select a submission below'
        : _readText(selectedReport, const [
            'supervisor_name',
          ], 'Unknown Supervisor');

    return ResponsivePageLayout(
      currentPage: 'Reports',
      title: 'Reports',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Subtitle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supervisor Report Summary',
                        style: TextStyle(
                          color: Color(0xFF0C1935),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$selectedProjectLabel\nSupervisor: $selectedSupervisorLabel',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
                  ),
                ] else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supervisor Report Summary',
                        style: TextStyle(
                          color: Color(0xFF0C1935),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$selectedProjectLabel • Supervisor: $selectedSupervisorLabel',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: _pickReportDate,
                                icon: Icon(
                                  Icons.calendar_today,
                                  size: isMobile ? 16 : 18,
                                ),
                                label: Text(
                                  _dateFmt.format(_weekStart),
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildReportsSearchField(isMobile),
                    ],
                  )
                else
                  Row(
                    children: [
                      Card(
                        color: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: _pickReportDate,
                                icon: Icon(
                                  Icons.calendar_today,
                                  size: isMobile ? 16 : 18,
                                ),
                                label: Text(
                                  _dateFmt.format(_weekStart),
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildReportsSearchField(isMobile),
                    ],
                  ),

                const SizedBox(height: 12),

                Card(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 10 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supervisor Submitted Reports',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: isMobile ? 300 : 320,
                          child: _buildSubmittedReportsTable(
                            isMobile,
                            filteredReports,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          SizedBox(height: isMobile ? 80 : 12),
        ],
      ),
    );
  }
}

class SubmissionDetailsPage extends StatefulWidget {
  const SubmissionDetailsPage({super.key, required this.report});

  final Map<String, dynamic> report;

  @override
  State<SubmissionDetailsPage> createState() => _SubmissionDetailsPageState();
}

class _SubmissionDetailsPageState extends State<SubmissionDetailsPage> {
  final TextEditingController _workerSearchController = TextEditingController();
  String _workerSearchQuery = '';

  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _primary = Color(0xFF3B82F6);
  static const Color _success = Color(0xFF22C55E);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _overtime = Color(0xFFF59E0B);

  @override
  void dispose() {
    _workerSearchController.dispose();
    super.dispose();
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _budgetSummary() {
    final raw = widget.report['project_budget_summary'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  /// Fills available width (no horizontal scroll) via flex column widths.
  Widget _buildCompactWorkerSalaryTable(
    List<Map<String, dynamic>> workers,
    NumberFormat money,
  ) {
    const headStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: Color(0xFF374151),
    );
    const dataStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      color: Color(0xFF111827),
    );
    const dataNetStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _success,
    );

    Widget th(String label, {bool right = false}) {
      return Container(
        color: const Color(0xFFF3F4F6),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: headStyle,
          textAlign: right ? TextAlign.right : TextAlign.left,
        ),
      );
    }

    Widget td(Widget child, {required Color background}) {
      return Container(
        color: background,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: child,
      );
    }

    /// Keeps long peso strings inside narrow flex columns.
    Widget tcMoney(String s, {required Color background, TextStyle? textStyle}) {
      return Container(
        color: background,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 1),
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            s,
            style: textStyle ?? dataStyle,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.85),
        1: FlexColumnWidth(0.75),
        2: FlexColumnWidth(0.28),
        3: FlexColumnWidth(0.32),
        4: FlexColumnWidth(0.28),
        5: FlexColumnWidth(0.82),
        6: FlexColumnWidth(0.82),
        7: FlexColumnWidth(0.8),
        8: FlexColumnWidth(0.86),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.grey.shade200,
          width: 0.5,
        ),
        top: BorderSide(color: Colors.grey.shade200, width: 0.5),
        bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
      ),
      children: [
        TableRow(
          children: [
            th('Name'),
            th('Role'),
            th('D', right: true),
            th('H', right: true),
            th('OT', right: true),
            th('Gross', right: true),
            th('Ded', right: true),
            th('Adv', right: true),
            th('Net', right: true),
          ],
        ),
        ...workers.asMap().entries.map((e) {
          final index = e.key;
          final worker = e.value;
          final bg = index.isEven
              ? const Color(0xFFF9FAFB)
              : Colors.white;
          final workerName = (worker['name'] ?? 'Unknown Worker').toString();
          final workerRole = (worker['role'] ?? 'Worker').toString();
          final workerDays =
              int.tryParse((worker['day'] ?? '0').toString()) ?? 0;
          final workerHours = _asDouble(worker['hours']);
          final workerOtHours = _asDouble(worker['ot_hours']);
          final workerGross = _asDouble(worker['gross_pay']);
          final workerComputedSalary = _asDouble(worker['computed_salary']);
          final workerCashAdvance = _asDouble(worker['cash_advance']);
          final workerDeduct = reportWorkerTotalDeductions(worker);
          final rColor = _roleBadgeText(workerRole);
          final rBg = _roleBadgeBg(workerRole);

          return TableRow(
            children: [
              td(
                Text(
                  workerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dataStyle.copyWith(fontWeight: FontWeight.w600),
                ),
                background: bg,
              ),
              td(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: rBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    workerRole,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: rColor,
                    ),
                  ),
                ),
                background: bg,
              ),
              td(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$workerDays',
                    style: dataStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                background: bg,
              ),
              td(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    workerHours.toStringAsFixed(1),
                    style: dataStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                background: bg,
              ),
              td(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    workerOtHours.toStringAsFixed(1),
                    style: dataStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                background: bg,
              ),
              tcMoney(money.format(workerGross), background: bg),
              tcMoney(
                money.format(workerDeduct),
                background: bg,
              ),
              tcMoney(
                money.format(workerCashAdvance),
                background: bg,
              ),
              tcMoney(
                money.format(workerComputedSalary),
                background: bg,
                textStyle: dataNetStyle,
              ),
            ],
          );
        }),
      ],
    );
  }

  String _readText(Map<String, dynamic> map, List<String> keys, String fallback) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  DateTime? _parseSubmittedAt() {
    final raw = (widget.report['submitted_at'] ?? '').toString();
    return DateTime.tryParse(raw);
  }

  Color _roleBadgeBg(String role) {
    switch (role.toLowerCase()) {
      case 'mason':
        return const Color(0xFFDBEAFE);
      case 'painter':
        return const Color(0xFFEDE9FE);
      case 'carpenter':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _roleBadgeText(String role) {
    switch (role.toLowerCase()) {
      case 'mason':
        return const Color(0xFF1D4ED8);
      case 'painter':
        return const Color(0xFF7C3AED);
      case 'carpenter':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF374151);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

    final supervisorLabel = _readText(
      widget.report,
      const ['supervisor_name'],
      'Unknown Supervisor',
    );
    final projectId = _toInt(widget.report['project_id']);
    final projectLabel = _readText(
      widget.report,
      const ['project_name'],
      projectId == null ? 'Unknown Project' : 'Project #$projectId',
    );
    final workers = (widget.report['workers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((w) => Map<String, dynamic>.from(w))
        .toList();
    final totalsMap = widget.report['totals'] is Map
        ? Map<String, dynamic>.from(widget.report['totals'] as Map)
        : <String, dynamic>{};

    final query = _workerSearchQuery.trim().toLowerCase();
    final filteredWorkers = workers.where((worker) {
      if (query.isEmpty) return true;
      final name = (worker['name'] ?? '').toString().toLowerCase();
      final role = (worker['role'] ?? '').toString().toLowerCase();
      final days = (worker['day'] ?? '').toString().toLowerCase();
      final hours = (worker['hours'] ?? '').toString().toLowerCase();
      final ot = (worker['ot_hours'] ?? '').toString().toLowerCase();
      return name.contains(query) ||
          role.contains(query) ||
          days.contains(query) ||
          hours.contains(query) ||
          ot.contains(query);
    }).toList();

    final submittedAt = _parseSubmittedAt();
    final submittedDateText = submittedAt == null
        ? 'Unknown'
        : DateFormat('MMM d, yyyy • h:mm a').format(submittedAt);
    final reportStartText = (widget.report['report_start'] ?? '').toString().trim();
    final reportEndText = (widget.report['report_end'] ?? '').toString().trim();
    final coverage = reportStartText.isNotEmpty && reportEndText.isNotEmpty
        ? '$reportStartText to $reportEndText'
        : 'Not provided';

    final totalHours = _asDouble(totalsMap['total_hours']);
    final totalOt = _asDouble(totalsMap['total_ot']);
    final totalSalary = _asDouble(totalsMap['total_salary']);
    final totalDeductions = _asDouble(totalsMap['total_deductions']);
    final budgetSummary = _budgetSummary();
    final totalBudget = _asDouble(budgetSummary['total_budget']);
    final usedMaterials = _asDouble(budgetSummary['total_used_materials']);
    final usedPayroll = _asDouble(budgetSummary['total_used_payroll']);
    final remainingBudget = _asDouble(budgetSummary['remaining_budget']);

    return ResponsivePageLayout(
      currentPage: 'Reports',
      title: 'Supervisor Report Details',
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 900 ? 24.0 : 16.0;

          return Container(
            color: _bg,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: _textPrimary),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Supervisor Report Details',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Export report (CSV)',
                        onPressed: () => exportSupervisorReportCsv(
                          context,
                          widget.report,
                        ),
                        icon: const Icon(
                          Icons.download_rounded,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submission Details',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _DetailTile(
                                label: 'Supervisor Name',
                                value: supervisorLabel,
                              ),
                              const SizedBox(width: 10),
                              _DetailTile(
                                label: 'Project Name',
                                value: projectLabel,
                              ),
                              const SizedBox(width: 10),
                              _DetailTile(
                                label: 'Submitted At',
                                value: submittedDateText,
                              ),
                              const SizedBox(width: 10),
                              _DetailTile(label: 'Coverage', value: coverage),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (budgetSummary.isNotEmpty) ...[
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Budget Impact',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 210,
                                  child: _StatCard(
                                    icon: Icons.account_balance_wallet_outlined,
                                    label: 'Project Budget',
                                    value: money.format(totalBudget),
                                    color: _primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 210,
                                  child: _StatCard(
                                    icon: Icons.inventory_2_outlined,
                                    label: 'Used Materials',
                                    value: money.format(usedMaterials),
                                    color: _overtime,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 210,
                                  child: _StatCard(
                                    icon: Icons.payments_outlined,
                                    label: 'Used Payroll',
                                    value: money.format(usedPayroll),
                                    color: _danger,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 210,
                                  child: _StatCard(
                                    icon: Icons.savings_outlined,
                                    label: 'Remaining Budget',
                                    value: money.format(remainingBudget),
                                    color: _success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Summary',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 210,
                                child: _StatCard(
                                  icon: Icons.schedule,
                                  label: 'Total Hours',
                                  value: totalHours.toStringAsFixed(1),
                                  color: _primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 210,
                                child: _StatCard(
                                  icon: Icons.bolt,
                                  label: 'Overtime',
                                  value: totalOt.toStringAsFixed(1),
                                  color: _overtime,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 210,
                                child: _StatCard(
                                  icon: Icons.remove_circle_outline,
                                  label: 'Deductions',
                                  value: money.format(totalDeductions),
                                  color: _danger,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 210,
                                child: _StatCard(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: 'Computed Salary',
                                  value: money.format(totalSalary),
                                  color: _success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Worker salaries',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: constraints.maxWidth >= 700 ? 200 : 150,
                              height: 32,
                              child: TextField(
                                controller: _workerSearchController,
                                onChanged: (value) {
                                  setState(() {
                                    _workerSearchQuery = value;
                                  });
                                },
                                style: const TextStyle(fontSize: 12.5),
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: const TextStyle(fontSize: 12.5),
                                  prefixIcon: const Icon(Icons.search, size: 16),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0C1935),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (filteredWorkers.isEmpty)
                          Text(
                            workers.isEmpty
                                ? 'No workers included.'
                                : 'No matching workers found.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.grey[700],
                            ),
                          )
                        else
                          _buildCompactWorkerSalaryTable(filteredWorkers, money),
                      ],
                    ),
                  ),
                ],
              ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _HoverSurface extends StatefulWidget {
  const _HoverSurface({required this.child});

  final Widget child;

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, _hovered ? -2.0 : 0.0)
          ..scale(_hovered ? 1.005 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? const Color(0xFFFF7A18)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: _hovered
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(255, 122, 24, 0.30),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ]
              : const [],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: const TextStyle(fontFamily: 'Inter'),
          child: widget.child,
        ),
      ),
    );
  }
}
