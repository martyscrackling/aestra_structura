import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'widgets/sidebar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/app_config.dart';
import '../services/app_time_service.dart';
import '../services/app_theme_tokens.dart';
import 'widgets/mobile_bottom_nav.dart';
import 'widgets/dashboard_header.dart';
import '../services/date_utils.dart';

const double _dailyRegularHoursCap = 8.0;
const double _overtimeRateMultiplier = 1.5;
const double _regularHolidayMultiplier = 2.0; // 200% pay for worked hours
const double _specialHolidayMultiplier = 1.3; // 130% pay for worked hours

class AttendanceReport {
  AttendanceReport({
    required this.fieldWorkerId,
    required this.name,
    required this.role,
    required this.totalDaysPresent,
    required this.totalHours,
    required this.overtimeHours,
    required this.cashAdvance,
    required this.deduction,
    required this.damagesDeduction,
    this.damagesPmCovers = false,
    required this.damagesCategory,
    required this.damagesItem,
    required this.damagesPrice,
    required this.hourlyRate,
    required this.sssDeduction,
    required this.philhealthDeduction,
    required this.pagibigDeduction,
    this.regularHolidayHours = 0,
    this.regularHolidayOtHours = 0,
    this.specialHolidayHours = 0,
    this.specialHolidayOtHours = 0,
  });

  final int fieldWorkerId;
  final String name;
  final String role;
  final int totalDaysPresent;
  // Normal (non-holiday) regular hours.
  final double totalHours;
  // Normal (non-holiday) overtime hours.
  final double overtimeHours;
  final double cashAdvance;
  final double deduction;
  final double damagesDeduction;
  /// When true, damage cost is not deducted from the worker; attribution remains on record.
  final bool damagesPmCovers;
  final String? damagesCategory;
  final String? damagesItem;
  final double damagesPrice;
  final double hourlyRate;
  final double sssDeduction;
  final double philhealthDeduction;
  final double pagibigDeduction;

  // Hours worked on a Regular Holiday (200% multiplier).
  final double regularHolidayHours;
  final double regularHolidayOtHours;
  // Hours worked on a Special Non-Working Day (130% multiplier).
  final double specialHolidayHours;
  final double specialHolidayOtHours;

  double get regularHours => totalHours;

  // Combined hours across ALL buckets (non-holiday + regular holiday + special
  // holiday). Used for display in the main "Hours" column so workers who
  // happen to work on a holiday still see their real worked hours.
  double get totalAllHours =>
      totalHours + regularHolidayHours + specialHolidayHours;

  double get totalAllOvertimeHours =>
      overtimeHours + regularHolidayOtHours + specialHolidayOtHours;

  // Base (non-holiday) earnings.
  double get basePay =>
      regularHours * hourlyRate +
      overtimeHours * hourlyRate * _overtimeRateMultiplier;

  // Holiday-only earnings (already includes the holiday premium).
  double get regularHolidayPay =>
      regularHolidayHours * hourlyRate * _regularHolidayMultiplier +
      regularHolidayOtHours *
          hourlyRate *
          _regularHolidayMultiplier *
          _overtimeRateMultiplier;

  double get specialHolidayPay =>
      specialHolidayHours * hourlyRate * _specialHolidayMultiplier +
      specialHolidayOtHours *
          hourlyRate *
          _specialHolidayMultiplier *
          _overtimeRateMultiplier;

  double get holidayPay => regularHolidayPay + specialHolidayPay;

  // Bonus portion only (over and above what the same hours would have paid
  // at the normal rate).
  double get regularHolidayBonus =>
      regularHolidayHours * hourlyRate * (_regularHolidayMultiplier - 1.0) +
      regularHolidayOtHours *
          hourlyRate *
          _overtimeRateMultiplier *
          (_regularHolidayMultiplier - 1.0);

  double get specialHolidayBonus =>
      specialHolidayHours * hourlyRate * (_specialHolidayMultiplier - 1.0) +
      specialHolidayOtHours *
          hourlyRate *
          _overtimeRateMultiplier *
          (_specialHolidayMultiplier - 1.0);

  double get holidayBonusPay => regularHolidayBonus + specialHolidayBonus;

  bool get hasHolidayPay =>
      regularHolidayHours > 0 ||
      regularHolidayOtHours > 0 ||
      specialHolidayHours > 0 ||
      specialHolidayOtHours > 0;

  double get grossPay => basePay + holidayPay;

  double get totalGovernmentDeductions =>
      sssDeduction + philhealthDeduction + pagibigDeduction;

  /// True when a damage is recorded (attributed) for this worker, including PM-covered cost.
  bool get hasRecordedDamage =>
      damagesPmCovers || damagesDeduction > 0 || damagesPrice > 0;

  double get totalDeductions => deduction + damagesDeduction + totalGovernmentDeductions;

  double get computedSalary => grossPay - totalDeductions;
}

class ReportHistoryEntry {
  ReportHistoryEntry({
    required this.start,
    required this.end,
    required this.totalAmount,
    required this.workersCount,
  });

  final DateTime start;
  final DateTime end;
  final double totalAmount;
  final int workersCount;
}

class _WorkerTotals {
  int totalDaysPresent = 0;
  double totalHours = 0; // non-holiday regular hours
  double overtimeHours = 0; // non-holiday OT hours
  double regularHolidayHours = 0;
  double regularHolidayOtHours = 0;
  double specialHolidayHours = 0;
  double specialHolidayOtHours = 0;
}

class _SupervisorProjectOption {
  _SupervisorProjectOption({
    required this.projectId,
    required this.projectName,
  });

  final int projectId;
  final String projectName;
}

class ReportsPage extends StatefulWidget {
  final bool initialSidebarVisible;

  const ReportsPage({super.key, this.initialSidebarVisible = false});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Color neutral = AppColors.surface;
  final Color accent = AppColors.accent;
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final DateFormat _prettyDateFmt = DateFormat('MMM d, yyyy');
  final DateFormat _liveDateTimeFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  bool _isLoading = false;
  bool _isLoadingHistory = false;
  bool _isLoadingProjects = false;
  String? _loadError;
  late DateTime _liveNow;
  Timer? _liveClockTimer;

  @override
  void initState() {
    super.initState();
    _liveNow = AppTimeService.now();
    _liveClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _liveNow = AppTimeService.now();
      });
    });

    final now = AppTimeService.now();
    _weekEnd = DateTime(now.year, now.month, now.day);
    _weekStart = _weekEnd;
    _salaryDate = _weekEnd;
    _effectiveReportStart = _weekStart;
    _initializeReportScope();
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    super.dispose();
  }

  void _navigateToPage(String page) {
    switch (page) {
      case 'Dashboard':
        context.go('/supervisor');
        break;
      case 'Projects':
        context.go('/supervisor/projects');
        break;
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Reports':
        return; // Already on reports page
      case 'Inventory':
        context.go('/supervisor/inventory');
        break;
      default:
        return;
    }
  }

  late DateTime _weekStart;
  late DateTime _weekEnd;
  late DateTime _salaryDate;
  late DateTime _effectiveReportStart;

  List<AttendanceReport> _rows = [];
  List<ReportHistoryEntry> _history = [];
  List<_SupervisorProjectOption> _supervisorProjects = [];
  int? _selectedProjectId;
  final Map<int, List<Map<String, dynamic>>> _workersCacheByProject =
      <int, List<Map<String, dynamic>>>{};

  /// One bulk attendance fetch is reused for the main week + 4 history windows.
  int? _attendanceBulkCacheProjectId;
  List<Map<String, dynamic>>? _attendanceBulkCache;
  DateTime? _attendanceBulkCacheAt;
  static const _attendanceBulkTtl = Duration(minutes: 2);

  void _invalidateAttendanceBulkCache() {
    _attendanceBulkCacheProjectId = null;
    _attendanceBulkCache = null;
    _attendanceBulkCacheAt = null;
  }

  final _money = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  Future<void> _initializeReportScope() async {
    await _loadSupervisorProjects();
    await _restorePersistedSalaryDate();
    // Load current week first (fills attendance cache); then history reuses the same data.
    await _refreshReports();
    if (mounted) {
      unawaited(_loadReportsHistory());
    }
  }

  String _salaryDatePrefsKey({required int projectId}) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser ?? <String, dynamic>{};
    final supervisorId =
        _toInt(currentUser['supervisor_id']) ??
        _toInt(currentUser['user_id']) ??
        _toInt(currentUser['id']) ??
        0;
    return 'supervisor_salary_date_v1:$supervisorId:$projectId';
  }

  Future<void> _persistSalaryDate() async {
    final projectId = _activeProjectId();
    if (projectId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _salaryDatePrefsKey(projectId: projectId),
      _dateString(_salaryDate),
    );
  }

  Future<void> _restorePersistedSalaryDate() async {
    final projectId = _activeProjectId();
    if (projectId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_salaryDatePrefsKey(projectId: projectId));
    if (raw == null || raw.trim().isEmpty) return;

    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return;

    if (!mounted) return;
    setState(() {
      _salaryDate = DateTime(parsed.year, parsed.month, parsed.day);
    });
  }

  int? _activeProjectId() {
    if (_selectedProjectId != null) return _selectedProjectId;
    final authService = Provider.of<AuthService>(context, listen: false);
    return _toInt(authService.currentUser?['project_id']);
  }

  String _activeProjectName() {
    for (final project in _supervisorProjects) {
      if (project.projectId == _activeProjectId()) {
        return project.projectName;
      }
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser ?? <String, dynamic>{};
    return (currentUser['project_name'] ??
            currentUser['assigned_project_name'] ??
            '')
        .toString()
        .trim();
  }

  Future<void> _loadSupervisorProjects() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser ?? <String, dynamic>{};
      final userId = _toInt(currentUser['user_id']);
      final typeOrRole = (currentUser['type'] ?? currentUser['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final supervisorId =
          _toInt(currentUser['supervisor_id']) ??
          ((typeOrRole == 'supervisor') ? userId : null);

      final Uri url;
      if (supervisorId != null) {
        url = AppConfig.apiUri('projects/?supervisor_id=$supervisorId');
      } else if (userId != null) {
        url = AppConfig.apiUri('projects/?user_id=$userId');
      } else {
        url = AppConfig.apiUri('projects/');
      }

      final response = await http.get(url);
      final options = <_SupervisorProjectOption>[];

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawProjects = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> && decoded['results'] is List
                  ? decoded['results'] as List<dynamic>
                  : const <dynamic>[]);

        for (final item in rawProjects) {
          if (item is! Map) continue;
          final project = Map<String, dynamic>.from(item);
          final id = _toInt(project['project_id'] ?? project['id']);
          final name = (project['project_name'] ?? project['name'] ?? '')
              .toString()
              .trim();
          if (id != null && name.isNotEmpty) {
            options.add(
              _SupervisorProjectOption(projectId: id, projectName: name),
            );
          }
        }
      }

      final currentProjectId = _toInt(currentUser['project_id']);
      final currentProjectName =
          (currentUser['project_name'] ??
                  currentUser['assigned_project_name'] ??
                  '')
              .toString()
              .trim();
      if (currentProjectId != null &&
          options.every((p) => p.projectId != currentProjectId)) {
        options.add(
          _SupervisorProjectOption(
            projectId: currentProjectId,
            projectName: currentProjectName.isEmpty
                ? 'Project #$currentProjectId'
                : currentProjectName,
          ),
        );
      }

      options.sort(
        (a, b) =>
            a.projectName.toLowerCase().compareTo(b.projectName.toLowerCase()),
      );

      int? selected = _selectedProjectId;
      if (selected == null && currentProjectId != null) {
        selected = currentProjectId;
      }
      if (selected != null && options.every((p) => p.projectId != selected)) {
        selected = options.isEmpty ? null : options.first.projectId;
      }
      selected ??= options.isEmpty ? null : options.first.projectId;

      if (!mounted) return;
      setState(() {
        _supervisorProjects = options;
        _selectedProjectId = selected;
      });
    } catch (_) {
      // Keep fallback behavior.
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingProjects = false;
      });
    }
  }

  Future<void> _submitToPM() async {
    await _refreshReports();
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser ?? <String, dynamic>{};
    final projectId = _activeProjectId();
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No project assigned to submit report.')),
      );
      return;
    }

    final payload = <String, dynamic>{
      'submission_id': '$projectId:${_dateString(_salaryDate)}',
      'project_id': projectId,
      'project_name':
          (currentUser['project_name'] ??
                  currentUser['assigned_project_name'] ??
                  '')
              .toString(),
      'supervisor_id':
          _toInt(currentUser['supervisor_id']) ?? _toInt(currentUser['id']),
      'supervisor_name':
          (currentUser['full_name'] ??
                  currentUser['name'] ??
                  currentUser['username'] ??
                  'Supervisor')
              .toString(),
      'submitted_at': DateTime.now().toIso8601String(),
      'salary_date': _dateString(_salaryDate),
      'report_start': _dateString(_effectiveReportStart),
      'report_end': _dateString(_weekEnd),
      'totals': {
        'total_hours': _totalHours,
        'total_ot': _totalOvertime,
        'total_salary': _totalComputedSalary,
        'total_deductions': _totalDeductions,
      },
      'workers': _rows
          .map(
            (r) => {
              'field_worker_id': r.fieldWorkerId,
              'name': r.name,
              'role': r.role,
              'day': r.totalDaysPresent,
              'hours': r.totalAllHours,
              'ot_hours': r.totalAllOvertimeHours,
              'hourly_rate': r.hourlyRate,
              'cash_advance': r.cashAdvance,
              'deduction': r.deduction,
              'total_deductions': r.totalDeductions,
              'damages_deduction': r.damagesDeduction,
              'damages_pm_covers': r.damagesPmCovers,
              'gross_pay': r.grossPay,
              'computed_salary': r.computedSalary,
            },
          )
          .toList(),
    };

    var stored = Map<String, dynamic>.from(payload);
    try {
      final response = await http.post(
        AppConfig.apiUri('supervisor-reports/'),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 201) {
        String msg =
            'Could not send report to the server (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            msg = decoded['detail'].toString();
          }
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        stored = Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Local cache (optional); project manager list is loaded from the API.
    final prefs = await SharedPreferences.getInstance();
    final existingRaw = prefs.getString('supervisor_submitted_reports_v1');
    final existingList = existingRaw == null
        ? <dynamic>[]
        : (jsonDecode(existingRaw) as List<dynamic>);

    final filtered = existingList.where((entry) {
      if (entry is! Map) return true;
      final map = Map<String, dynamic>.from(entry);
      return map['submission_id'] != stored['submission_id'];
    }).toList();
    filtered.add(stored);

    await prefs.setString(
      'supervisor_submitted_reports_v1',
      jsonEncode(filtered),
    );
    await prefs.setString('pm_latest_report_v1', jsonEncode(stored));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report sent to the Project Manager (saved on the server)'),
        backgroundColor: Color(0xFF0C1935),
      ),
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int? _workerIdFromWorkerPayload(Map<String, dynamic> worker) {
    return _toInt(worker['fieldworker_id'] ?? worker['id']);
  }

  void _syncSavedWorkerPayroll({
    required int workerId,
    required double cashAdvanceBalance,
    required double deductionPerSalary,
  }) {
    final projectId = _activeProjectId();

    setState(() {
      _rows = _rows
          .map((row) {
            if (row.fieldWorkerId != workerId) return row;
            return AttendanceReport(
              fieldWorkerId: row.fieldWorkerId,
              name: row.name,
              role: row.role,
              totalDaysPresent: row.totalDaysPresent,
              totalHours: row.totalHours,
              overtimeHours: row.overtimeHours,
              cashAdvance: cashAdvanceBalance,
              deduction: deductionPerSalary,
              damagesDeduction: row.damagesDeduction,
              damagesPmCovers: row.damagesPmCovers,
              damagesCategory: row.damagesCategory,
              damagesItem: row.damagesItem,
              damagesPrice: row.damagesPrice,
              hourlyRate: row.hourlyRate,
              sssDeduction: row.sssDeduction,
              philhealthDeduction: row.philhealthDeduction,
              pagibigDeduction: row.pagibigDeduction,
              regularHolidayHours: row.regularHolidayHours,
              regularHolidayOtHours: row.regularHolidayOtHours,
              specialHolidayHours: row.specialHolidayHours,
              specialHolidayOtHours: row.specialHolidayOtHours,
            );
          })
          .toList(growable: false);

      if (projectId != null) {
        final cachedWorkers = _workersCacheByProject[projectId];
        if (cachedWorkers != null) {
          for (final worker in cachedWorkers) {
            if (_workerIdFromWorkerPayload(worker) == workerId) {
              worker['cash_advance_balance'] = cashAdvanceBalance;
              worker['deduction_per_salary'] = deductionPerSalary;
              break;
            }
          }
        }
      }
    });
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  String _dateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _inclusiveDays(DateTime start, DateTime end) {
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    return b.difference(a).inDays + 1;
  }

  bool get _isSalaryDayMode =>
      _dateString(_weekEnd) == _dateString(_salaryDate);

  Future<DateTime> _resolveSalaryCycleStartDate({
    required int projectId,
    required DateTime endDate,
  }) async {
    final response = await http.get(
      AppConfig.apiUri('attendance/?project_id=$projectId'),
    );
    if (response.statusCode != 200) return endDate;

    final rows = (jsonDecode(response.body) as List<dynamic>)
        .whereType<Map<String, dynamic>>();

    DateTime? earliest;
    for (final row in rows) {
      final rawDate = (row['attendance_date'] ?? '').toString().trim();
      if (rawDate.isEmpty || rawDate == 'null') continue;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;

      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (day.isAfter(endDate)) continue;
      if (earliest == null || day.isBefore(earliest)) {
        earliest = day;
      }
    }

    return earliest ?? endDate;
  }

  double _resolveWeeklyDeduction(
    Map<String, dynamic> worker,
    String totalKey,
    String minKey,
  ) {
    final total = _toDouble(worker[totalKey]);
    if (total > 0) return total;
    final min = _toDouble(worker[minKey]);
    if (min > 0) return min;
    return 0;
  }

  DateTime? _combineDateAndTime(DateTime date, String? rawTime) {
    final parts = _parseTimeParts(rawTime);
    if (parts == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      parts.$1,
      parts.$2,
      parts.$3,
    );
  }

  (int, int, int)? _parseTimeParts(String? rawTime) {
    if (rawTime == null || rawTime.trim().isEmpty) return null;
    final text = rawTime.trim();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?$',
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final second = int.tryParse(match.group(3) ?? '0') ?? 0;
    if (hour == null || minute == null) return null;

    final meridiem = (match.group(4) ?? '').toLowerCase();
    if (meridiem == 'am') {
      if (hour == 12) hour = 0;
    } else if (meridiem == 'pm') {
      if (hour < 12) hour += 12;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute, second);
  }

  int? _timeToMinutes(String? rawTime) {
    final parts = _parseTimeParts(rawTime);
    if (parts == null) return null;
    return parts.$1 * 60 + parts.$2;
  }

  int? _workerIdFromAttendance(Map<String, dynamic> record) {
    final raw = record['field_worker_id'] ?? record['field_worker'];
    if (raw is Map<String, dynamic>) {
      return _toInt(raw['fieldworker_id'] ?? raw['id']);
    }
    return _toInt(raw);
  }

  double _workedHoursForRecord(Map<String, dynamic> record, DateTime date) {
    final inTime = _combineDateAndTime(
      date,
      (record['check_in_time'] ?? '').toString(),
    );
    final outTime = _combineDateAndTime(
      date,
      (record['check_out_time'] ?? '').toString(),
    );
    if (inTime == null || outTime == null || !outTime.isAfter(inTime)) return 0;

    var minutes = outTime.difference(inTime).inMinutes;

    final breakIn = _combineDateAndTime(
      date,
      (record['break_in_time'] ?? '').toString(),
    );
    final breakOut = _combineDateAndTime(
      date,
      (record['break_out_time'] ?? '').toString(),
    );
    if (breakIn != null && breakOut != null && breakOut.isAfter(breakIn)) {
      minutes -= breakOut.difference(breakIn).inMinutes;
    }

    if (minutes < 0) return 0;
    return minutes / 60.0;
  }

  double _dailyOvertimeHours(double workedHours) {
    if (workedHours <= _dailyRegularHoursCap) return 0;
    return workedHours - _dailyRegularHoursCap;
  }

  double _dailyRegularHours(double workedHours) {
    if (workedHours <= 0) return 0;
    return workedHours > _dailyRegularHoursCap
        ? _dailyRegularHoursCap
        : workedHours;
  }

  Future<List<Map<String, dynamic>>> _fetchWorkers(int projectId) async {
    final cached = _workersCacheByProject[projectId];
    if (cached != null && cached.isNotEmpty) {
      return cached
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser ?? <String, dynamic>{};
    final typeOrRole = (currentUser['type'] ?? currentUser['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final userId = _toInt(currentUser['user_id']);
    final supervisorId =
        _toInt(currentUser['supervisor_id']) ??
        _toInt(currentUser['id']) ??
        ((typeOrRole == 'supervisor') ? userId : null);

    final workersById = <int, Map<String, dynamic>>{};

    // Use the same source as Attendance page so subtask-assigned workers are included.
    try {
      final dateStr = _dateString(_weekEnd);
      final overviewQuery = supervisorId != null
          ? 'attendance/supervisor-overview/?project_id=$projectId&attendance_date=$dateStr&supervisor_id=$supervisorId'
          : 'attendance/supervisor-overview/?project_id=$projectId&attendance_date=$dateStr';
      final overviewResponse = await http.get(AppConfig.apiUri(overviewQuery));
      if (overviewResponse.statusCode == 200) {
        final decoded = jsonDecode(overviewResponse.body);
        if (decoded is Map<String, dynamic> && decoded['field_workers'] is List) {
          final overviewWorkers = (decoded['field_workers'] as List<dynamic>)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false);
          for (final worker in overviewWorkers) {
            final workerId = _workerIdFromWorkerPayload(worker);
            if (workerId == null) continue;
            workersById[workerId] = worker;
          }
        }
      }
    } catch (_) {
      // Continue with field-workers endpoints.
    }

    final candidateQueries = <String>{
      'field-workers/?project_id=$projectId',
      if (userId != null) 'field-workers/?project_id=$projectId&user_id=$userId',
    };
    if (supervisorId != null) {
      candidateQueries.add(
        'field-workers/?project_id=$projectId&supervisor_id=$supervisorId',
      );
    }

    int? lastStatus;
    for (final query in candidateQueries) {
      final workersResponse = await http.get(AppConfig.apiUri(query));
      lastStatus = workersResponse.statusCode;
      if (workersResponse.statusCode != 200) {
        continue;
      }

      final decoded = jsonDecode(workersResponse.body);
      final workersData = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['results'] is List
                ? decoded['results'] as List<dynamic>
                : const <dynamic>[]);

      final workers = workersData
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      for (final worker in workers) {
        final workerId = _workerIdFromWorkerPayload(worker);
        if (workerId == null) continue;
        workersById[workerId] = worker;
      }
    }

    if (workersById.isEmpty && lastStatus != null && lastStatus != 200) {
      throw Exception('Failed to load workers ($lastStatus)');
    }

    final mergedWorkers = workersById.values
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    if (mergedWorkers.isNotEmpty) {
      _workersCacheByProject[projectId] = mergedWorkers
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return mergedWorkers;
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceForDate(
    int projectId,
    DateTime date,
    Set<int> workerIds,
  ) async {
    final response = await http.get(
      AppConfig.apiUri(
        'attendance/?project_id=$projectId&attendance_date=${_dateString(date)}',
      ),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load attendance for ${_dateString(date)} (${response.statusCode})',
      );
    }
    final scopedRows = (jsonDecode(response.body) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where((row) {
          final workerId = _workerIdFromAttendance(row);
          return workerId != null && workerIds.contains(workerId);
        })
        .toList();

    final coveredWorkers = scopedRows
        .map(_workerIdFromAttendance)
        .whereType<int>()
        .toSet();
    if (coveredWorkers.length == workerIds.length || workerIds.isEmpty) {
      return scopedRows;
    }

    // Keep reports strictly scoped to selected project.
    return scopedRows;
  }

  Future<int> _countWorkedDaysForWorkerUntil({
    required int projectId,
    required int workerId,
    required DateTime endDate,
  }) async {
    final response = await http.get(
      AppConfig.apiUri(
        'attendance/?project_id=$projectId&field_worker_id=$workerId',
      ),
    );
    if (response.statusCode != 200) return 0;

    final rows = (jsonDecode(response.body) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();

    final mergedByDate = <String, Map<String, dynamic>>{};
    for (final record in rows) {
      final rawDate = (record['attendance_date'] ?? '').toString().trim();
      if (rawDate.isEmpty || rawDate == 'null') continue;

      final parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate == null) continue;

      final date = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      if (date.isAfter(endDate)) continue;
      final dateKey = _dateString(date);

      final merged = mergedByDate.putIfAbsent(dateKey, () {
        return <String, dynamic>{
          'check_in_time': '',
          'check_out_time': '',
          'break_in_time': '',
          'break_out_time': '',
        };
      });

      final inTime = (record['check_in_time'] ?? '').toString();
      final outTime = (record['check_out_time'] ?? '').toString();
      final breakIn = (record['break_in_time'] ?? '').toString();
      final breakOut = (record['break_out_time'] ?? '').toString();

      final mergedIn = (merged['check_in_time'] ?? '').toString();
      final mergedOut = (merged['check_out_time'] ?? '').toString();
      final mergedBreakIn = (merged['break_in_time'] ?? '').toString();
      final mergedBreakOut = (merged['break_out_time'] ?? '').toString();

      final inMinutes = _timeToMinutes(inTime);
      final mergedInMinutes = _timeToMinutes(mergedIn);
      if (inMinutes != null &&
          (mergedInMinutes == null || inMinutes < mergedInMinutes)) {
        merged['check_in_time'] = inTime;
      }

      final outMinutes = _timeToMinutes(outTime);
      final mergedOutMinutes = _timeToMinutes(mergedOut);
      if (outMinutes != null &&
          (mergedOutMinutes == null || outMinutes > mergedOutMinutes)) {
        merged['check_out_time'] = outTime;
      }

      final breakInMinutes = _timeToMinutes(breakIn);
      final mergedBreakInMinutes = _timeToMinutes(mergedBreakIn);
      if (breakInMinutes != null &&
          (mergedBreakInMinutes == null ||
              breakInMinutes < mergedBreakInMinutes)) {
        merged['break_in_time'] = breakIn;
      }

      final breakOutMinutes = _timeToMinutes(breakOut);
      final mergedBreakOutMinutes = _timeToMinutes(mergedBreakOut);
      if (breakOutMinutes != null &&
          (mergedBreakOutMinutes == null ||
              breakOutMinutes > mergedBreakOutMinutes)) {
        merged['break_out_time'] = breakOut;
      }
    }

    var workedDayCount = 0;
    for (final entry in mergedByDate.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null) continue;
      final workedHours = _workedHoursForRecord(entry.value, date);
      if (workedHours > 0) workedDayCount += 1;
    }
    return workedDayCount;
  }

  Future<void> _updateWorkerCashAdvanceSettings({
    required int workerId,
    required double cashAdvanceBalance,
    required double deductionPerSalary,
  }) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser ?? <String, dynamic>{};
    final projectId = _toInt(currentUser['project_id']);
    final typeOrRole = (currentUser['type'] ?? currentUser['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final userId = _toInt(currentUser['user_id']);
    final supervisorId =
        _toInt(currentUser['supervisor_id']) ??
        ((typeOrRole == 'supervisor') ? userId : null);

    final scopeQuery = supervisorId != null
        ? '?supervisor_id=$supervisorId'
        : (projectId != null ? '?project_id=$projectId' : '');

    final response = await http.patch(
      AppConfig.apiUri('field-workers/$workerId/$scopeQuery'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cash_advance_balance': cashAdvanceBalance,
        'deduction_per_salary': deductionPerSalary,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          detail = (decoded['detail'] ?? decoded['message'] ?? response.body)
              .toString();
        }
      } catch (_) {
        // Keep raw response body as detail.
      }
      throw Exception(
        'Failed to update cash advance settings (${response.statusCode}): $detail',
      );
    }
  }

  Future<List<AttendanceReport>> _buildReportsForRange({
    required int projectId,
    required DateTime start,
    required DateTime end,
  }) async {
    final workers = await _fetchWorkers(projectId);
    final workersById = <int, Map<String, dynamic>>{};
    for (final worker in workers) {
      final workerId = _toInt(worker['fieldworker_id']);
      if (workerId != null) {
        workersById[workerId] = worker;
      }
    }

    final totalsByWorker = <int, _WorkerTotals>{};
    final countedPresencePerDay = <String>{};
    final workerIds = workersById.keys.toSet();

    final dates = <DateTime>[];
    for (
      DateTime date = DateTime(start.year, start.month, start.day);
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      dates.add(date);
    }

    // Reuse one bulk attendance response for main report + 4 history windows.
    final List<Map<String, dynamic>> allAttendance;
    final now = DateTime.now();
    if (_attendanceBulkCacheProjectId == projectId &&
        _attendanceBulkCache != null &&
        _attendanceBulkCacheAt != null &&
        now.difference(_attendanceBulkCacheAt!) < _attendanceBulkTtl) {
      allAttendance = _attendanceBulkCache!;
    } else {
      final response = await http.get(
        AppConfig.apiUri('attendance/?project_id=$projectId'),
      );
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load attendance data (${response.statusCode})',
        );
      }
      allAttendance = (jsonDecode(response.body) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      _attendanceBulkCacheProjectId = projectId;
      _attendanceBulkCache = allAttendance;
      _attendanceBulkCacheAt = now;
    }

    // Group attendance records by date for easy lookup.
    final attendanceByDateMap = <String, List<Map<String, dynamic>>>{};
    for (final record in allAttendance) {
      final rawDate = (record['attendance_date'] ?? '').toString().trim();
      if (rawDate.isEmpty || rawDate == 'null') continue;
      final parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate == null) continue;
      final dateKey = _dateString(parsedDate);
      attendanceByDateMap.putIfAbsent(dateKey, () => []).add(record);
    }

    for (final date in dates) {
      final dateKey = _dateString(date);
      final attendance = attendanceByDateMap[dateKey] ?? [];
      final mergedByWorker = <int, Map<String, dynamic>>{};

      for (final record in attendance) {
        final workerId = _workerIdFromAttendance(record);
        if (workerId == null || !workersById.containsKey(workerId)) continue;

        final merged = mergedByWorker.putIfAbsent(workerId, () {
          return <String, dynamic>{
            'field_worker': workerId,
            'check_in_time': '',
            'check_out_time': '',
            'status': '',
          };
        });

        final inTime = (record['check_in_time'] ?? '').toString();
        final outTime = (record['check_out_time'] ?? '').toString();
        final status = (record['status'] ?? '').toString();

        final mergedIn = (merged['check_in_time'] ?? '').toString();
        final mergedOut = (merged['check_out_time'] ?? '').toString();

        final inMinutes = _timeToMinutes(inTime);
        final mergedInMinutes = _timeToMinutes(mergedIn);
        if (inMinutes != null &&
            (mergedInMinutes == null || inMinutes < mergedInMinutes)) {
          merged['check_in_time'] = inTime;
        }

        final outMinutes = _timeToMinutes(outTime);
        final mergedOutMinutes = _timeToMinutes(mergedOut);
        if (outMinutes != null &&
            (mergedOutMinutes == null || outMinutes > mergedOutMinutes)) {
          merged['check_out_time'] = outTime;
        }

        if (status == 'on_site' || status == 'on_break') {
          merged['status'] = status;
        }
      }

      for (final entry in mergedByWorker.entries) {
        final workerId = entry.key;
        final record = entry.value;

        final totals = totalsByWorker.putIfAbsent(workerId, _WorkerTotals.new);
        final dayKey = '$workerId:${_dateString(date)}';
        final workedHours = _workedHoursForRecord(record, date);
        if (workedHours > 0 && !countedPresencePerDay.contains(dayKey)) {
          totals.totalDaysPresent += 1;
          countedPresencePerDay.add(dayKey);
        }

        final regHrs = _dailyRegularHours(workedHours);
        final otHrs = _dailyOvertimeHours(workedHours);
        final holidayInfo = PhilippineDateUtils.getHolidayInfo(date);
        if (holidayInfo == null) {
          totals.totalHours += regHrs;
          totals.overtimeHours += otHrs;
        } else if (holidayInfo.isRegular) {
          totals.regularHolidayHours += regHrs;
          totals.regularHolidayOtHours += otHrs;
        } else {
          totals.specialHolidayHours += regHrs;
          totals.specialHolidayOtHours += otHrs;
        }
      }
    }

    final reports = <AttendanceReport>[];
    for (final workerEntry in workersById.entries) {
      final workerId = workerEntry.key;
      final worker = workerEntry.value;
      final totals = totalsByWorker[workerId] ?? _WorkerTotals();
      final hasAnyHours =
          totals.totalHours > 0 ||
          totals.overtimeHours > 0 ||
          totals.regularHolidayHours > 0 ||
          totals.regularHolidayOtHours > 0 ||
          totals.specialHolidayHours > 0 ||
          totals.specialHolidayOtHours > 0;
      if (!hasAnyHours) {
        continue;
      }

      final cumulativeWorkedDays = totals.totalDaysPresent;

      final firstName = (worker['first_name'] ?? '').toString().trim();
      final lastName = (worker['last_name'] ?? '').toString().trim();
      final fullName = ('$firstName $lastName').trim();
      final hourlyRate = _toDouble(worker['payrate']);

      final periodDays = _inclusiveDays(start, end);
      final periodFactor = periodDays / 7.0;

      final sssWeekly = _resolveWeeklyDeduction(
        worker,
        'sss_weekly_total',
        'sss_weekly_min',
      );
      final philhealthWeekly = _resolveWeeklyDeduction(
        worker,
        'philhealth_weekly_total',
        'philhealth_weekly_min',
      );
      final pagibigWeekly = _resolveWeeklyDeduction(
        worker,
        'pagibig_weekly_total',
        'pagibig_weekly_min',
      );

      // Fallback for older worker records that don't have computed deduction fields yet.
      // totalHours is regular-only (non-holiday); OT is stored in overtimeHours.
      final regularHours = totals.totalHours < 0 ? 0.0 : totals.totalHours;
      final regHolPay =
          totals.regularHolidayHours * hourlyRate * _regularHolidayMultiplier +
          totals.regularHolidayOtHours *
              hourlyRate *
              _regularHolidayMultiplier *
              _overtimeRateMultiplier;
      final spcHolPay =
          totals.specialHolidayHours * hourlyRate * _specialHolidayMultiplier +
          totals.specialHolidayOtHours *
              hourlyRate *
              _specialHolidayMultiplier *
              _overtimeRateMultiplier;
      final grossPayEstimate =
          regularHours * hourlyRate +
          totals.overtimeHours * hourlyRate * _overtimeRateMultiplier +
          regHolPay +
          spcHolPay;
      final sssDeduction = sssWeekly > 0
          ? sssWeekly * periodFactor
          : grossPayEstimate * 0.0323;
      final philhealthDeduction = philhealthWeekly > 0
          ? philhealthWeekly * periodFactor
          : grossPayEstimate * 0.0115;
      final pagibigDeduction = pagibigWeekly > 0
          ? pagibigWeekly * periodFactor
          : ((grossPayEstimate > 1154.73 ? 1154.73 : grossPayEstimate) *
                0.0046);

      reports.add(
        AttendanceReport(
          fieldWorkerId: workerId,
          name: fullName.isEmpty ? 'Worker #$workerId' : fullName,
          role: (worker['role'] ?? 'Worker').toString(),
          totalDaysPresent: cumulativeWorkedDays,
          totalHours: totals.totalHours,
          overtimeHours: totals.overtimeHours,
          cashAdvance: _toDouble(
            worker['cash_advance_balance'] ??
                worker['cash_advance'] ??
                worker['cashAdvance'] ??
                0,
          ),
          deduction: _toDouble(
            worker['deduction_per_salary'] ??
                worker['deduction'] ??
                worker['other_deduction'] ??
                0,
          ),
          damagesDeduction: _toDouble(
            worker['damages_deduction_per_salary'] ??
                worker['damages_deduction'] ??
                0,
          ),
          damagesPmCovers: _toBool(worker['damages_pm_covers']),
          damagesCategory: worker['damages_category']?.toString(),
          damagesItem: worker['damages_item']?.toString(),
          damagesPrice: _toDouble(worker['damages_price']),
          hourlyRate: hourlyRate,
          sssDeduction: sssDeduction,
          philhealthDeduction: philhealthDeduction,
          pagibigDeduction: pagibigDeduction,
          regularHolidayHours: totals.regularHolidayHours,
          regularHolidayOtHours: totals.regularHolidayOtHours,
          specialHolidayHours: totals.specialHolidayHours,
          specialHolidayOtHours: totals.specialHolidayOtHours,
        ),
      );
    }

    reports.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return reports;
  }

  Future<void> _refreshReports() async {
    if (!mounted) return;
    _invalidateAttendanceBulkCache();
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final projectId = _activeProjectId();
      if (projectId == null) {
        throw Exception('No project selected for this report.');
      }

      DateTime start = _weekStart;
      if (_isSalaryDayMode) {
        start = await _resolveSalaryCycleStartDate(
          projectId: projectId,
          endDate: _weekEnd,
        );
      }

      final reports = await _buildReportsForRange(
        projectId: projectId,
        start: start,
        end: _weekEnd,
      );

      if (!mounted) return;
      setState(() {
        _rows = reports;
        _effectiveReportStart = start;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = [];
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshReportsInBackground() async {
    if (!mounted) return;

    try {
      final projectId = _activeProjectId();
      if (projectId == null) return;

      DateTime start = _weekStart;
      if (_isSalaryDayMode) {
        start = await _resolveSalaryCycleStartDate(
          projectId: projectId,
          endDate: _weekEnd,
        );
      }

      final reports = await _buildReportsForRange(
        projectId: projectId,
        start: start,
        end: _weekEnd,
      );

      if (!mounted) return;
      setState(() {
        _rows = reports;
        _effectiveReportStart = start;
        _loadError = null;
      });
    } catch (_) {
      // Keep current UI values when silent background refresh fails.
    }
  }

  Future<void> _loadReportsHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final projectId = _activeProjectId();
      if (projectId == null) {
        if (!mounted) return;
        setState(() {
          _history = [];
        });
        return;
      }

      final windows = List.generate(4, (index) {
        final i = index + 1;
        final end = _weekStart.subtract(Duration(days: 7 * (i - 1) + 1));
        final start = end.subtract(const Duration(days: 6));
        return (start: start, end: end);
      });

      final history = await Future.wait<ReportHistoryEntry>(
        windows.map((window) async {
          final rows = await _buildReportsForRange(
            projectId: projectId,
            start: window.start,
            end: window.end,
          );
          final totalAmount = rows.fold<double>(
            0,
            (sum, r) => sum + r.computedSalary,
          );
          return ReportHistoryEntry(
            start: window.start,
            end: window.end,
            totalAmount: totalAmount,
            workersCount: rows.where((r) => r.totalAllHours > 0).length,
          );
        }),
      );

      if (!mounted) return;
      setState(() {
        _history = history;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _history = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  // Show reports history dialog
  void _showReportsHistory() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: accent, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Reports History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Historical records based on API data
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: _isLoadingHistory
                        ? const [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ]
                        : _history.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No historical report data found.',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ]
                        : _history
                              .map(
                                (entry) => _historyItem(
                                  'Week of ${_prettyDateFmt.format(entry.start)} - ${_prettyDateFmt.format(entry.end)}',
                                  'Workers with attendance: ${entry.workersCount}',
                                  _money.format(entry.totalAmount),
                                  entry.totalAmount > 0
                                      ? 'Available'
                                      : 'No payout',
                                  entry.totalAmount > 0
                                      ? const Color(0xFF757575)
                                      : const Color(0xFFFF8F00),
                                ),
                              )
                              .toList(),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyItem(
    String period,
    String submittedDate,
    String totalAmount,
    String status,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.description, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  submittedDate,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalAmount,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('View details for $period')),
              );
            },
            icon: const Icon(Icons.visibility, size: 20),
            tooltip: 'View Details',
          ),
        ],
      ),
    );
  }

  double _effectiveDeduction(AttendanceReport r) =>
      _isSalaryDayMode ? r.deduction : 0.0;
  double _effectiveDamages(AttendanceReport r) =>
      _isSalaryDayMode ? r.damagesDeduction : 0.0;
  double _effectiveTotalDeductions(AttendanceReport r) =>
      r.totalGovernmentDeductions +
      _effectiveDeduction(r) +
      _effectiveDamages(r);
  double _effectiveNetSalary(AttendanceReport r) =>
      r.grossPay - _effectiveTotalDeductions(r);

  double get _totalDeductions =>
      _rows.fold(0.0, (t, r) => t + _effectiveTotalDeductions(r));
  double get _totalComputedSalary =>
      _rows.fold(0.0, (t, r) => t + _effectiveNetSalary(r));
  double get _totalOvertime =>
      _rows.fold(0.0, (t, r) => t + r.totalAllOvertimeHours);
  double get _totalHours =>
      _rows.fold(0.0, (t, r) => t + r.totalAllHours);
  double get _totalSSS => _rows.fold(0.0, (t, r) => t + r.sssDeduction);
  double get _totalPhilhealth =>
      _rows.fold(0.0, (t, r) => t + r.philhealthDeduction);
  double get _totalPagibig => _rows.fold(0.0, (t, r) => t + r.pagibigDeduction);
  double get _totalDamages =>
      _rows.fold(0.0, (t, r) => t + _effectiveDamages(r));
  double get _totalHolidayPay =>
      _rows.fold(0.0, (t, r) => t + r.holidayPay);
  double get _totalHolidayBonus =>
      _rows.fold(0.0, (t, r) => t + r.holidayBonusPay);

  Future<void> _pickReportDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _weekEnd,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            dialogBackgroundColor: Colors.white,
            dialogTheme: theme.dialogTheme.copyWith(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            datePickerTheme: theme.datePickerTheme.copyWith(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) {
      final selected = DateTime(d.year, d.month, d.day);
      setState(() {
        _weekEnd = selected;
        _weekStart = selected;
      });
      await _refreshReports();
      if (mounted) {
        unawaited(_loadReportsHistory());
      }
    }
  }

  Future<void> _pickSalaryDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _salaryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            dialogBackgroundColor: Colors.white,
            dialogTheme: theme.dialogTheme.copyWith(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            datePickerTheme: theme.datePickerTheme.copyWith(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) {
      setState(() {
        _salaryDate = DateTime(d.year, d.month, d.day);
      });
      await _persistSalaryDate();
    }
  }

  Future<void> _onProjectChanged(int? projectId) async {
    if (projectId == null || projectId == _selectedProjectId) return;
    _invalidateAttendanceBulkCache();
    setState(() {
      _selectedProjectId = projectId;
    });
    await _restorePersistedSalaryDate();
    await _refreshReports();
    if (mounted) {
      unawaited(_loadReportsHistory());
    }
  }

  Widget _kpiCard(String title, String value, {Color? color, IconData? icon}) {
    return Expanded(
      child: Card(
        color: Colors.white,
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
      ),
    );
  }

  Widget _mobileDatePickerButton({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        visualDensity: VisualDensity.compact,
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
    final deductionStr = _money.format(r.deduction);
    final cashAdvanceStr = _money.format(r.cashAdvance);
    return Card(
      color: Colors.white,
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
                        'Day ${r.totalDaysPresent}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${r.totalAllHours.toStringAsFixed(1)} hrs',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 12),
                      if (r.totalAllOvertimeHours > 0)
                        Chip(
                          label: Text(
                            '+${r.totalAllOvertimeHours.toStringAsFixed(1)} OT',
                          ),
                          backgroundColor: const Color(
                            0xFFFF8F00,
                          ).withOpacity(0.12),
                          labelStyle: const TextStyle(color: Color(0xFFFF6F00)),
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
                if (_isSalaryDayMode) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Cash Adv. Deduct: $deductionStr',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

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
              if (isDesktop) Sidebar(activePage: 'Reports', keepVisible: true),
              Expanded(
                child: Column(
                  children: [
                    const DashboardHeader(title: 'Reports'),

                    const SizedBox(height: 16),

                    // Date controls (hidden on mobile)
                    if (!isMobile)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                          children: [
                            // report date selector
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: TextButton.icon(
                                onPressed: _pickReportDate,
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: Color(0xFF0C1935),
                                ),
                                label: Text(
                                  _dateFmt.format(_weekEnd),
                                  style: const TextStyle(
                                    color: Color(0xFF0C1935),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: TextButton.icon(
                                onPressed: _pickSalaryDate,
                                icon: const Icon(
                                  Icons.payments_outlined,
                                  size: 18,
                                  color: Color(0xFF0C1935),
                                ),
                                label: Text(
                                  'Salary: ${_dateFmt.format(_salaryDate)}',
                                  style: const TextStyle(
                                    color: Color(0xFF0C1935),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.apartment,
                                    size: 18,
                                    color: Color(0xFF0C1935),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 200,
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _selectedProjectId,
                                        dropdownColor: Colors.white,
                                        isExpanded: true,
                                        isDense: true,
                                        hint: Text(
                                          _isLoadingProjects
                                              ? 'Loading projects...'
                                              : 'Select Project',
                                        ),
                                        items: _supervisorProjects
                                            .map(
                                              (project) => DropdownMenuItem<int>(
                                                value: project.projectId,
                                                child: Text(
                                                  project.projectName,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _isLoadingProjects
                                            ? null
                                            : (value) {
                                                _onProjectChanged(value);
                                              },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isSalaryDayMode) const SizedBox(width: 10),
                            if (_isSalaryDayMode)
                              ElevatedButton.icon(
                                onPressed: _submitToPM,
                                icon: const Icon(Icons.send, size: 18),
                                label: const Text('Submit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ),
                      ),
                    if (!isMobile && _isSalaryDayMode)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            'Salary Day Summary (Day 1 to ${_dateFmt.format(_weekEnd)}): Total Hours ${_totalHours.toStringAsFixed(1)} | Total OT ${_totalOvertime.toStringAsFixed(1)} | Total Salary ${_money.format(_totalComputedSalary)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    if (!isMobile) const SizedBox(height: 16),

                    // Table view
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 24,
                          vertical: 8,
                        ),
                        child: isMobile
                            ? Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.borderSubtle,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _mobileDatePickerButton(
                                                label: 'Report Date',
                                                value: _dateFmt.format(
                                                  _weekEnd,
                                                ),
                                                icon: Icons.calendar_today,
                                                onTap: _pickReportDate,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: _mobileDatePickerButton(
                                                label: 'Salary Date',
                                                value: _dateFmt.format(
                                                  _salaryDate,
                                                ),
                                                icon: Icons.payments_outlined,
                                                onTap: _pickSalaryDate,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<int>(
                                          value: _selectedProjectId,
                                          dropdownColor: Colors.white,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: 'Project',
                                            prefixIcon: const Icon(
                                              Icons.apartment,
                                              size: 18,
                                            ),
                                            isDense: true,
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 10,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFE5E7EB),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFE5E7EB),
                                              ),
                                            ),
                                          ),
                                          hint: const Text('Select Project'),
                                          items: _supervisorProjects
                                              .map(
                                                (project) =>
                                                    DropdownMenuItem<int>(
                                                      value: project.projectId,
                                                      child: Text(
                                                        project.projectName,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                              )
                                              .toList(),
                                          onChanged: _isLoadingProjects
                                              ? null
                                              : (value) {
                                                  _onProjectChanged(value);
                                                },
                                        ),
                                        if (_isSalaryDayMode)
                                          const SizedBox(height: 6),
                                        if (_isSalaryDayMode)
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: _submitToPM,
                                              icon: const Icon(
                                                Icons.send,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Submit Report',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.accent,
                                                foregroundColor: Colors.white,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Mobile compact list
                                  Expanded(
                                    child: _isLoading
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : _loadError != null
                                        ? Center(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              child: Text(
                                                _loadError!,
                                                style: TextStyle(
                                                  color: Colors.red[700],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          )
                                        : _rows.isEmpty
                                        ? Center(
                                            child: Text(
                                              'No attendance data for selected date',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: _rows.length + 1,
                                            itemBuilder: (context, i) {
                                              if (i == _rows.length) {
                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 4,
                                                    bottom: 6,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.05),
                                                        blurRadius: 8,
                                                        offset: const Offset(
                                                          0,
                                                          -2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      if (_totalHolidayPay >
                                                          0) ...[
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Holiday Pay',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey[700],
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            Text(
                                                              _money.format(
                                                                _totalHolidayPay,
                                                              ),
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize: 13,
                                                                color: Color(
                                                                  0xFF9D174D,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                      ],
                                                      if (_totalDamages > 0) ...[
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Damages',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey[700],
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            Text(
                                                              _money.format(
                                                                _totalDamages,
                                                              ),
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize: 13,
                                                                color: Color(
                                                                  0xFFFF7A18,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                      ],
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            'Total Deductions',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[700],
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          Text(
                                                            _money.format(
                                                              _totalDeductions,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 13,
                                                                  color: Colors
                                                                      .redAccent,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Divider(
                                                        height: 1,
                                                        color: Colors.grey[300],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          const Text(
                                                            'Total Net Salary',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                          Text(
                                                            _money.format(
                                                              _totalComputedSalary,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }

                                              final r = _rows[i];
                                              final initials = r.name
                                                  .split(' ')
                                                  .map(
                                                    (s) => s.isNotEmpty
                                                        ? s[0]
                                                        : '',
                                                  )
                                                  .take(2)
                                                  .join();

                                              return Card(
                                                color: Colors.white,
                                                margin: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                elevation: 1,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: InkWell(
                                                  onTap: () =>
                                                      _showWorkerDetails(r),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        // Avatar
                                                        Container(
                                                          width: 42,
                                                          height: 42,
                                                          decoration: BoxDecoration(
                                                            color: accent
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              initials,
                                                              style: TextStyle(
                                                                color: accent,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        // Worker info
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                r.name,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 3,
                                                              ),
                                                              Wrap(
                                                                spacing: 6,
                                                                runSpacing: 3,
                                                                children: [
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: AppColors
                                                                          .surfaceMuted,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            6,
                                                                          ),
                                                                    ),
                                                                    child: ConstrainedBox(
                                                                      constraints: const BoxConstraints(
                                                                        maxWidth:
                                                                            100,
                                                                      ),
                                                                      child: Text(
                                                                        r.role,
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              10,
                                                                          color:
                                                                              AppColors.textMuted,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    '${r.totalAllHours.toStringAsFixed(1)} hrs',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: AppColors
                                                                          .textMuted,
                                                                    ),
                                                                  ),
                                                                  if (r.hasHolidayPay)
                                                                    _holidayPill(
                                                                      r,
                                                                      fontSize:
                                                                          9,
                                                                    ),
                                                                  if (r
                                                                      .hasRecordedDamage)
                                                                    _damagePill(
                                                                      r,
                                                                      fontSize:
                                                                          9,
                                                                    ),
                                                                  if (r.totalAllOvertimeHours >
                                                                      0)
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            5,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: AppColors
                                                                            .accent
                                                                            .withOpacity(
                                                                              0.12,
                                                                            ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              4,
                                                                            ),
                                                                      ),
                                                                      child: Text(
                                                                        '+${r.totalAllOvertimeHours.toStringAsFixed(1)} OT',
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              9,
                                                                          color:
                                                                              AppColors.accent,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        // Net salary
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            Text(
                                                              _money.format(
                                                                _effectiveNetSalary(
                                                                  r,
                                                                ),
                                                              ),
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .green,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              'Net Salary',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        IconButton(
                                                          onPressed: () =>
                                                              _showWorkerDetails(
                                                                r,
                                                              ),
                                                          icon: const Icon(
                                                            Icons.visibility,
                                                            size: 18,
                                                          ),
                                                          padding:
                                                              const EdgeInsets.all(
                                                                4,
                                                              ),
                                                          constraints:
                                                              const BoxConstraints(),
                                                          tooltip: 'Summary',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              )
                            : Card(
                                color: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Table Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          topRight: Radius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Worker',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Role',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Hours',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Gross Pay',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'SSS',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'PhilHealth',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Pag-IBIG',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          if (_isSalaryDayMode)
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Deductions',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.grey[800],
                                                  fontSize: 13,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Net Salary',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Summary',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Table Body
                                    Expanded(
                                      child: _isLoading
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : _loadError != null
                                          ? Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                child: Text(
                                                  _loadError!,
                                                  style: TextStyle(
                                                    color: Colors.red[700],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            )
                                          : _rows.isEmpty
                                          ? Center(
                                              child: Text(
                                                'No attendance data for selected date',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: _rows.length,
                                              itemBuilder: (context, i) {
                                                final r = _rows[i];
                                                final initials = r.name
                                                    .split(' ')
                                                    .map(
                                                      (s) => s.isNotEmpty
                                                          ? s[0]
                                                          : '',
                                                    )
                                                    .take(2)
                                                    .join();
                                                final isEven = i.isEven;

                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isEven
                                                        ? Colors.grey.shade50
                                                        : Colors.white,
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade200,
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // Worker (with avatar)
                                                      Expanded(
                                                        flex: 3,
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              width: 36,
                                                              height: 36,
                                                              decoration: BoxDecoration(
                                                                color: accent
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  initials,
                                                                  style: TextStyle(
                                                                    color:
                                                                        accent,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 10,
                                                            ),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Text(
                                                                    r.name,
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                  if (r.hasHolidayPay ||
                                                                      r
                                                                          .hasRecordedDamage) ...[
                                                                    const SizedBox(
                                                                      height: 4,
                                                                    ),
                                                                    Wrap(
                                                                      spacing:
                                                                          4,
                                                                      runSpacing:
                                                                          3,
                                                                      children: [
                                                                        if (r.hasHolidayPay)
                                                                          _holidayPill(
                                                                            r,
                                                                          ),
                                                                        if (r
                                                                            .hasRecordedDamage)
                                                                          _damagePill(
                                                                            r,
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      // Role
                                                      Expanded(
                                                        flex: 2,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .grey
                                                                .shade100,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            r.role,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ),

                                                      // Total Hours (including OT indicator)
                                                      Expanded(
                                                        flex: 2,
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              r.totalAllHours
                                                                  .toStringAsFixed(
                                                                    1,
                                                                  ),
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey[700],
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                            if (r.totalAllOvertimeHours >
                                                                0)
                                                              Text(
                                                                '+${r.totalAllOvertimeHours.toStringAsFixed(1)} OT',
                                                                style: const TextStyle(
                                                                  color: Color(
                                                                    0xFFFF6F00,
                                                                  ),
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                          ],
                                                        ),
                                                      ),

                                                      // Gross Pay
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          _money.format(
                                                            r.grossPay,
                                                          ),
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[800],
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          textAlign:
                                                              TextAlign.right,
                                                        ),
                                                      ),

                                                      // SSS Deduction
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          _money.format(
                                                            r.sssDeduction,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors.blue,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                          textAlign:
                                                              TextAlign.right,
                                                        ),
                                                      ),

                                                      // PhilHealth Deduction
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          _money.format(
                                                            r.philhealthDeduction,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors.blue,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                          textAlign:
                                                              TextAlign.right,
                                                        ),
                                                      ),

                                                      // Pag-IBIG Deduction
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          _money.format(
                                                            r.pagibigDeduction,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .lightBlue,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                          textAlign:
                                                              TextAlign.right,
                                                        ),
                                                      ),

                                                      // Other Deductions (Cash Advance + Other)
                                                      if (_isSalaryDayMode)
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                            _money.format(
                                                              r.deduction + r.damagesDeduction,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .redAccent,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),

                                                      // Net Salary
                                                      Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          _money.format(
                                                            _effectiveNetSalary(
                                                              r,
                                                            ),
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .green,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                          textAlign:
                                                              TextAlign.right,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Align(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: OutlinedButton.icon(
                                                            onPressed: () =>
                                                                _showWorkerDetails(
                                                                  r,
                                                                ),
                                                            icon: const Icon(
                                                              Icons.visibility,
                                                              size: 16,
                                                            ),
                                                            label: const Text(
                                                              'View',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            style: OutlinedButton.styleFrom(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical: 6,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                    ),

                                    // Totals summary footer
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'SSS',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _money.format(_totalSSS),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 20),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'PhilHealth',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _money.format(_totalPhilhealth),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 20),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Pag-IBIG',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _money.format(_totalPagibig),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: Colors.lightBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 20),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Holiday Pay',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _money.format(_totalHolidayPay),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: Color(0xFF9D174D),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 20),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Damages',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _money.format(_totalDamages),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: Color(0xFFFF7A18),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 20),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Total Deductions',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _money.format(_totalDeductions),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 30),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Total Net Salary',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _money.format(
                                                  _totalComputedSalary,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 18,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // Bottom navigation bar for mobile only
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
    );
  }

  Widget _buildBottomNavBar() {
    return SupervisorMobileBottomNav(
      activeTab: SupervisorMobileTab.more,
      activeMorePage: 'Reports',
      onSelect: _navigateToPage,
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final color = isActive ? AppColors.accent : Colors.white70;

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
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.mobileNavLabel(color, isActive: isActive),
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
          color: AppColors.navSurface,
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
              _buildMoreOption(Icons.file_copy, 'Reports', 'Reports', true),
              _buildMoreOption(
                Icons.inventory,
                'Inventory',
                'Inventory',
                false,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOption(
    IconData icon,
    String title,
    String page,
    bool isActive,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? const Color(0xFFFF6F00) : Colors.white70,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? const Color(0xFFFF6F00) : Colors.white,
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _navigateToPage(page);
      },
    );
  }

  // Show detailed worker salary breakdown in a modal
  void _showWorkerDetails(AttendanceReport r) {
    final isSalaryDay = _isSalaryDayMode;
    final cashAdvanceController = TextEditingController(text: '0.00');
    final deductionController = TextEditingController(
      text: (isSalaryDay ? r.deduction : 0).toStringAsFixed(2),
    );
    double editableCashAdvance = r.cashAdvance;
    double cashAdvanceRequest = 0;
    double editableDeduction = isSalaryDay ? r.deduction : 0;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final effectiveDeduction = isSalaryDay ? editableDeduction : 0.0;
          final effectiveDamages = isSalaryDay ? r.damagesDeduction : 0.0;
          final hasDamage = r.hasRecordedDamage;
          final liveTotalDeductions =
              r.totalGovernmentDeductions +
              effectiveDeduction +
              effectiveDamages;
          final liveNetSalary = r.grossPay - liveTotalDeductions;
          final damageRepaymentPeriods =
              !r.damagesPmCovers && r.damagesDeduction > 0
                  ? (r.damagesPrice / r.damagesDeduction).ceil()
                  : 0;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Worker header
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              r.name
                                  .split(' ')
                                  .map((s) => s.isNotEmpty ? s[0] : '')
                                  .take(2)
                                  .join(),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
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
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Attendance info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _detailItem(
                            'Days',
                            '${r.totalDaysPresent}',
                            Icons.calendar_today,
                          ),
                          _detailItem(
                            'Hours',
                            r.totalAllHours.toStringAsFixed(1),
                            Icons.access_time,
                          ),
                          _detailItem(
                            'OT',
                            r.totalAllOvertimeHours.toStringAsFixed(1),
                            Icons.add_circle_outline,
                          ),
                          _detailItem(
                            'Rate',
                            '${_money.format(r.hourlyRate)}/hr',
                            Icons.attach_money,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        'Summary period: ${_dateFmt.format(_effectiveReportStart)} to ${_dateFmt.format(_weekEnd)} | Salary date: ${_dateFmt.format(_salaryDate)}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cash advance controls
                    const Text(
                      'Cash Advance Controls',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD7A8)),
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Current Balance: ${_money.format(editableCashAdvance)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (!isSalaryDay)
                            TextField(
                              controller: cashAdvanceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Cash Advance Request (PHP)',
                                prefixText: '₱ ',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (val) {
                                final parsed = _toDouble(val);
                                setModalState(() {
                                  cashAdvanceRequest = parsed < 0 ? 0 : parsed;
                                });
                              },
                            ),
                          if (!isSalaryDay) const SizedBox(height: 10),
                          if (isSalaryDay)
                            TextField(
                              controller: deductionController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Deduction Per Salary (PHP)',
                                prefixText: '₱ ',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (val) {
                                final parsed = _toDouble(val);
                                setModalState(() {
                                  final normalized = parsed < 0 ? 0.0 : parsed;
                                  editableDeduction =
                                      normalized > editableCashAdvance
                                      ? editableCashAdvance
                                      : normalized;
                                });
                              },
                            ),
                          if (isSalaryDay)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Deduction is available only on salary day and cannot exceed current balance.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          if (!isSalaryDay)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Deduction will be available on salary day.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setModalState(() {
                                        isSaving = true;
                                      });
                                      try {
                                        final nextBalance = isSalaryDay
                                            ? (editableCashAdvance -
                                                  effectiveDeduction)
                                            : (editableCashAdvance +
                                                  cashAdvanceRequest);
                                        if (!isSalaryDay &&
                                            cashAdvanceRequest <= 0) {
                                          throw Exception(
                                            'Enter a cash advance request amount greater than zero.',
                                          );
                                        }

                                        await _updateWorkerCashAdvanceSettings(
                                          workerId: r.fieldWorkerId,
                                          cashAdvanceBalance: nextBalance < 0
                                              ? 0
                                              : nextBalance,
                                          deductionPerSalary:
                                              effectiveDeduction,
                                        );
                                        setModalState(() {
                                          editableCashAdvance = nextBalance < 0
                                              ? 0
                                              : nextBalance;
                                          if (!isSalaryDay) {
                                            cashAdvanceRequest = 0;
                                            cashAdvanceController.text = '0.00';
                                          }
                                        });
                                        if (mounted) {
                                          _syncSavedWorkerPayroll(
                                            workerId: r.fieldWorkerId,
                                            cashAdvanceBalance:
                                                editableCashAdvance,
                                            deductionPerSalary:
                                                effectiveDeduction,
                                          );
                                          unawaited(
                                            _refreshReportsInBackground(),
                                          );
                                        }
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isSalaryDay
                                                  ? 'Salary-day deduction saved'
                                                  : 'Cash advance request added to balance',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      } finally {
                                        if (!mounted) return;
                                        setModalState(() {
                                          isSaving = false;
                                        });
                                      }
                                    },
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save, size: 16),
                              label: Text(
                                isSaving ? 'Saving...' : 'Save',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (r.hasHolidayPay) ...[
                      const Text(
                        'Holiday Pay',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFDF2F8), Color(0xFFEFF6FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFBCFE8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9D174D),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.celebration,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Holiday premiums this period',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF9D174D),
                                    ),
                                  ),
                                ),
                                Text(
                                  '+${_money.format(r.holidayBonusPay)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (r.regularHolidayHours > 0 ||
                                r.regularHolidayOtHours > 0)
                              _holidayBreakdownRow(
                                'Regular Holiday',
                                '200% pay',
                                r.regularHolidayHours,
                                r.regularHolidayOtHours,
                                r.regularHolidayPay,
                                const Color(0xFF9D174D),
                              ),
                            if ((r.regularHolidayHours > 0 ||
                                    r.regularHolidayOtHours > 0) &&
                                (r.specialHolidayHours > 0 ||
                                    r.specialHolidayOtHours > 0))
                              const SizedBox(height: 6),
                            if (r.specialHolidayHours > 0 ||
                                r.specialHolidayOtHours > 0)
                              _holidayBreakdownRow(
                                'Special Non-Working',
                                '130% pay',
                                r.specialHolidayHours,
                                r.specialHolidayOtHours,
                                r.specialHolidayPay,
                                const Color(0xFF075985),
                              ),
                            const SizedBox(height: 10),
                            Divider(height: 1, color: Colors.pink[100]),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Holiday Pay',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _money.format(r.holidayPay),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF9D174D),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (hasDamage) ...[
                      const Text(
                        'Damage on Record',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4EC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD1B0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF7A18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.report_gmailerrorred,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (r.damagesItem ?? '').isNotEmpty
                                            ? r.damagesItem!
                                            : 'Reported Damage',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xFF7A3B00),
                                        ),
                                      ),
                                      if ((r.damagesCategory ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            r.damagesCategory!.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFB45309),
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _damageStat(
                                    'Total Damage',
                                    _money.format(r.damagesPrice),
                                    const Color(0xFFB45309),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 34,
                                  color: const Color(0xFFFFD1B0),
                                ),
                                Expanded(
                                  child: _damageStat(
                                    r.damagesPmCovers
                                        ? 'Worker pays'
                                        : 'Per Salary',
                                    r.damagesPmCovers
                                        ? '—'
                                        : '- ${_money.format(r.damagesDeduction)}',
                                    r.damagesPmCovers
                                        ? const Color(0xFF0F766E)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                                if (damageRepaymentPeriods > 0) ...[
                                  Container(
                                    width: 1,
                                    height: 34,
                                    color: const Color(0xFFFFD1B0),
                                  ),
                                  Expanded(
                                    child: _damageStat(
                                      'Est. Periods',
                                      '$damageRepaymentPeriods',
                                      const Color(0xFF7A3B00),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (damageRepaymentPeriods > 0) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Approx. $damageRepaymentPeriods salary period${damageRepaymentPeriods == 1 ? '' : 's'} to fully repay at current rate.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7A3B00),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            if (r.damagesPmCovers)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 12,
                                      color: Color(0xFF0F766E),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Project covers cost · worker not deducted',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSalaryDay
                                      ? const Color(0xFFFFE4D0)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSalaryDay
                                          ? Icons.check_circle
                                          : Icons.schedule,
                                      size: 12,
                                      color: isSalaryDay
                                          ? const Color(0xFFB45309)
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isSalaryDay
                                          ? 'Deducting this salary day'
                                          : 'Not deducted today · only on salary day',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSalaryDay
                                            ? const Color(0xFFB45309)
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Salary breakdown
                    const Text(
                      'Salary Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _salaryRow(
                      'Gross Pay',
                      _money.format(r.grossPay),
                      Colors.black,
                      isBold: true,
                    ),
                    if (r.hasHolidayPay) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _salaryRow(
                          'Base Pay',
                          _money.format(r.basePay),
                          Colors.grey[700] ?? Colors.grey,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _salaryRow(
                          'Holiday Pay',
                          '+ ${_money.format(r.holidayPay)}',
                          const Color(0xFF9D174D),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Divider(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 8),

                    const Text(
                      'Deductions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _salaryRow(
                      'SSS',
                      '- ${_money.format(r.sssDeduction)}',
                      Colors.blue,
                    ),
                    _salaryRow(
                      'PhilHealth',
                      '- ${_money.format(r.philhealthDeduction)}',
                      Colors.blue,
                    ),
                    _salaryRow(
                      'Pag-IBIG',
                      '- ${_money.format(r.pagibigDeduction)}',
                      Colors.lightBlue,
                    ),
                    _salaryRow(
                      'Cash Advance Balance',
                      _money.format(editableCashAdvance),
                      Colors.orange,
                    ),
                    _salaryRow(
                      'Deduction Per Salary',
                      '- ${_money.format(effectiveDeduction)}',
                      Colors.redAccent,
                    ),
                    if (r.damagesPmCovers && r.hasRecordedDamage)
                      _salaryRow(
                        (r.damagesItem ?? '').isNotEmpty
                            ? 'Damage (${r.damagesItem}) · PM'
                            : 'Damage (PM covered)',
                        'No worker deduction',
                        const Color(0xFF0F766E),
                      )
                    else if (r.damagesDeduction > 0)
                      _salaryRow(
                        (r.damagesItem ?? '').isNotEmpty
                            ? 'Damage (${r.damagesItem})'
                            : 'Damage',
                        '- ${_money.format(effectiveDamages)}',
                        const Color(0xFFFF7A18),
                      ),

                    const SizedBox(height: 12),
                    Divider(height: 1, thickness: 2, color: Colors.grey[400]),
                    const SizedBox(height: 12),

                    _salaryRow(
                      'Total Deductions',
                      _money.format(liveTotalDeductions),
                      Colors.redAccent,
                      isBold: true,
                    ),
                    const SizedBox(height: 16),

                    // Net salary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Net Salary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _money.format(liveNetSalary),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _holidayBreakdownRow(
    String title,
    String rateLabel,
    double hours,
    double otHours,
    double pay,
    Color color,
  ) {
    final hoursText = hours > 0 ? '${hours.toStringAsFixed(1)}h' : '';
    final otText = otHours > 0 ? '+${otHours.toStringAsFixed(1)}h OT' : '';
    final hoursDisplay = [
      hoursText,
      otText,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            rateLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (hoursDisplay.isNotEmpty)
                Text(
                  hoursDisplay,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
            ],
          ),
        ),
        Text(
          _money.format(pay),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _damageStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7A3B00),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _holidayPill(AttendanceReport r, {double fontSize = 10}) {
    if (!r.hasHolidayPay) return const SizedBox.shrink();
    final hasRegular =
        r.regularHolidayHours > 0 || r.regularHolidayOtHours > 0;
    final hasSpecial =
        r.specialHolidayHours > 0 || r.specialHolidayOtHours > 0;
    final label = hasRegular && hasSpecial
        ? 'HOL'
        : hasRegular
        ? 'HOL 200%'
        : 'HOL 130%';
    final bg = hasRegular
        ? const Color(0xFFFCE7F3) // soft pink for regular holiday (higher rate)
        : const Color(0xFFE0F2FE); // soft sky for special
    final border = hasRegular
        ? const Color(0xFFFBCFE8)
        : const Color(0xFFBAE6FD);
    final fg = hasRegular
        ? const Color(0xFF9D174D)
        : const Color(0xFF075985);
    final bonus = r.holidayBonusPay;
    return InkWell(
      onTap: () => _showWorkerDetails(r),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: 11, color: fg),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (bonus > 0) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '+${_money.format(bonus)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _damagePill(AttendanceReport r, {double fontSize = 10}) {
    final item = r.damagesItem ?? '';
    final label = item.isNotEmpty ? item.toUpperCase() : 'DAMAGE';
    final effective = _effectiveDamages(r);
    final String priceLabel;
    if (r.damagesPmCovers) {
      if (r.damagesPrice > 0) {
        priceLabel = 'PM·${_money.format(r.damagesPrice)}';
      } else {
        priceLabel = 'PM';
      }
    } else {
      priceLabel = effective > 0 ? '-${_money.format(effective)}' : '';
    }
    return InkWell(
      onTap: () => _showWorkerDetails(r),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFE0),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFFD1B0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.report_gmailerrorred,
              size: 11,
              color: Color(0xFFB45309),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7A3B00),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (priceLabel.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  priceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: r.damagesPmCovers
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _salaryRow(
    String label,
    String amount,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
