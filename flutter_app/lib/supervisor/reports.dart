import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'widgets/sidebar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/app_config.dart';
import '../services/app_time_service.dart';
import 'widgets/supervisor_user_badge.dart';

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
    required this.hourlyRate,
    required this.sssDeduction,
    required this.philhealthDeduction,
    required this.pagibigDeduction,
  });

  final int fieldWorkerId;
  final String name;
  final String role;
  final int totalDaysPresent;
  final double totalHours;
  final double overtimeHours;
  final double cashAdvance;
  final double deduction;
  final double hourlyRate;
  final double sssDeduction;
  final double philhealthDeduction;
  final double pagibigDeduction;

  double get regularHours {
    final regular = totalHours - overtimeHours;
    return regular < 0 ? 0 : regular;
  }

  double get grossPay =>
      regularHours * hourlyRate + overtimeHours * hourlyRate * 1.5;

  double get totalGovernmentDeductions =>
      sssDeduction + philhealthDeduction + pagibigDeduction;

  double get totalDeductions =>
      deduction + totalGovernmentDeductions;

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
  double totalHours = 0;
  double overtimeHours = 0;
}

class ReportsPage extends StatefulWidget {
  final bool initialSidebarVisible;

  const ReportsPage({super.key, this.initialSidebarVisible = false});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Color neutral = const Color(0xFFF4F6F9);
  final Color accent = const Color(0xFFFF6F00);
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final DateFormat _prettyDateFmt = DateFormat('MMM d, yyyy');
  final DateFormat _liveDateTimeFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  bool _isLoading = false;
  bool _isLoadingHistory = false;
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
    _weekStart = _weekEnd.subtract(Duration(days: _weekEnd.weekday - 1));
    _refreshReports();
    _loadReportsHistory();
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
      case 'Workers':
      case 'Worker Management':
        context.go('/supervisor/workers');
        break;
      case 'Attendance':
        context.go('/supervisor/attendance');
        break;
      case 'Logs':
      case 'Daily Logs':
        context.go('/supervisor/daily-logs');
        break;
      case 'Tasks':
      case 'Task Progress':
        context.go('/supervisor/task-progress');
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

  List<AttendanceReport> _rows = [];
  List<ReportHistoryEntry> _history = [];

  final _money = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  Future<void> _submitToPM() async {
    await _refreshReports();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report data synced from server')),
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _dateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _inclusiveDays(DateTime start, DateTime end) {
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    return b.difference(a).inDays + 1;
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
    if (rawTime == null || rawTime.trim().isEmpty) return null;
    final normalized = rawTime.split('.').first;
    final pieces = normalized.split(':');
    if (pieces.length < 2) return null;
    final hour = int.tryParse(pieces[0]);
    final minute = int.tryParse(pieces[1]);
    final second = pieces.length > 2 ? int.tryParse(pieces[2]) ?? 0 : 0;
    if (hour == null || minute == null) return null;
    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  bool _isPresent(Map<String, dynamic> record) {
    final checkIn = (record['check_in_time'] ?? '').toString();
    if (checkIn.isNotEmpty) return true;
    final status = (record['status'] ?? '').toString();
    return status == 'on_site' || status == 'on_break';
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

  Future<List<Map<String, dynamic>>> _fetchWorkers(int projectId) async {
    final workersResponse = await http.get(
      AppConfig.apiUri('field-workers/?project_id=$projectId'),
    );
    if (workersResponse.statusCode != 200) {
      throw Exception('Failed to load workers (${workersResponse.statusCode})');
    }
    final workersData = jsonDecode(workersResponse.body) as List<dynamic>;
    return workersData.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceForDate(
    int projectId,
    DateTime date,
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
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _updateWorkerCashAdvanceSettings({
    required int workerId,
    required double cashAdvanceBalance,
    required double deductionPerSalary,
  }) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser ?? <String, dynamic>{};
    final projectId = _toInt(currentUser['project_id']);
    final typeOrRole =
        (currentUser['type'] ?? currentUser['role'] ?? '')
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

    for (
      DateTime date = DateTime(start.year, start.month, start.day);
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      final attendance = await _fetchAttendanceForDate(projectId, date);
      for (final record in attendance) {
        final workerId = _toInt(record['field_worker']);
        if (workerId == null || !workersById.containsKey(workerId)) continue;

        final totals = totalsByWorker.putIfAbsent(workerId, _WorkerTotals.new);
        final dayKey = '$workerId:${_dateString(date)}';
        if (_isPresent(record) && !countedPresencePerDay.contains(dayKey)) {
          totals.totalDaysPresent += 1;
          countedPresencePerDay.add(dayKey);
        }

        final workedHours = _workedHoursForRecord(record, date);
        totals.totalHours += workedHours;
        totals.overtimeHours += workedHours > 8 ? workedHours - 8 : 0;
      }
    }

    final reports = <AttendanceReport>[];
    workersById.forEach((workerId, worker) {
      final totals = totalsByWorker[workerId] ?? _WorkerTotals();
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
        final regularHours = (totals.totalHours - totals.overtimeHours) < 0
          ? 0.0
          : (totals.totalHours - totals.overtimeHours);
        final grossPayEstimate =
          regularHours * hourlyRate + totals.overtimeHours * hourlyRate * 1.5;
      final sssDeduction = sssWeekly > 0
          ? sssWeekly * periodFactor
          : grossPayEstimate * 0.0323;
      final philhealthDeduction = philhealthWeekly > 0
          ? philhealthWeekly * periodFactor
          : grossPayEstimate * 0.0115;
      final pagibigDeduction = pagibigWeekly > 0
          ? pagibigWeekly * periodFactor
          : ((grossPayEstimate > 1154.73 ? 1154.73 : grossPayEstimate) * 0.0046);

      reports.add(
        AttendanceReport(
          fieldWorkerId: workerId,
          name: fullName.isEmpty ? 'Worker #$workerId' : fullName,
          role: (worker['role'] ?? 'Worker').toString(),
          totalDaysPresent: totals.totalDaysPresent,
          totalHours: totals.totalHours,
          overtimeHours: totals.overtimeHours,
          cashAdvance: _toDouble(
            worker['cash_advance_balance'] ?? worker['cash_advance'] ?? worker['cashAdvance'] ?? 0,
          ),
          deduction: _toDouble(
            worker['deduction_per_salary'] ?? worker['deduction'] ?? worker['other_deduction'] ?? 0,
          ),
          hourlyRate: hourlyRate,
          sssDeduction: sssDeduction,
          philhealthDeduction: philhealthDeduction,
          pagibigDeduction: pagibigDeduction,
        ),
      );
    });

    reports.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return reports;
  }

  Future<void> _refreshReports() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectId = _toInt(authService.currentUser?['project_id']);
      if (projectId == null) {
        throw Exception('No project assigned to your account.');
      }

      final reports = await _buildReportsForRange(
        projectId: projectId,
        start: _weekStart,
        end: _weekEnd,
      );

      if (!mounted) return;
      setState(() {
        _rows = reports;
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

  Future<void> _loadReportsHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectId = _toInt(authService.currentUser?['project_id']);
      if (projectId == null) {
        if (!mounted) return;
        setState(() {
          _history = [];
        });
        return;
      }

      final history = <ReportHistoryEntry>[];
      for (var i = 1; i <= 4; i++) {
        final end = _weekStart.subtract(Duration(days: 7 * (i - 1) + 1));
        final start = end.subtract(const Duration(days: 6));
        final rows = await _buildReportsForRange(
          projectId: projectId,
          start: start,
          end: end,
        );
        final totalAmount = rows.fold<double>(0, (sum, r) => sum + r.computedSalary);
        history.add(
          ReportHistoryEntry(
            start: start,
            end: end,
            totalAmount: totalAmount,
            workersCount: rows.where((r) => r.totalHours > 0).length,
          ),
        );
      }

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
                                  entry.totalAmount > 0 ? 'Available' : 'No payout',
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

  double get _totalDeductions =>
      _rows.fold(0.0, (t, r) => t + r.totalDeductions);
  double get _totalComputedSalary =>
      _rows.fold(0.0, (t, r) => t + r.computedSalary);
  double get _totalOvertime => _rows.fold(0.0, (t, r) => t + r.overtimeHours);
  double get _totalHours => _rows.fold(0.0, (t, r) => t + r.totalHours);
  double get _totalSSS => _rows.fold(0.0, (t, r) => t + r.sssDeduction);
  double get _totalPhilhealth =>
      _rows.fold(0.0, (t, r) => t + r.philhealthDeduction);
  double get _totalPagibig => _rows.fold(0.0, (t, r) => t + r.pagibigDeduction);

  Future<void> _pickReportDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _weekEnd,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _weekEnd = DateTime(d.year, d.month, d.day);
        _weekStart = _weekEnd.subtract(Duration(days: _weekEnd.weekday - 1));
      });
      await _refreshReports();
      await _loadReportsHistory();
    }
  }

  Widget _kpiCard(String title, String value, {Color? color, IconData? icon}) {
    return Expanded(
      child: Card(
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
                const SizedBox(height: 6),
                Text(
                  'Cash Adv. Deduct: $deductionStr',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
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
                    // header with white background and slim blue line at left corner (keeps Notification bell & AESTRA)
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 24,
                        vertical: isMobile ? 12 : 18,
                      ),
                      child: Row(
                        children: [
                          // slim blue accent line in the left corner
                          Container(
                            width: isMobile ? 3 : 4,
                            height: isMobile ? 40 : 56,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weekly Attendance Report',
                                  style: TextStyle(
                                    color: const Color(0xFF0C1935),
                                    fontSize: isMobile ? 16 : 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!isMobile) const SizedBox(height: 6),
                                if (!isMobile)
                                  Text(
                                    _liveDateTimeFmt.format(_liveNow),
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                              ],
                            ),
                          ),
                          if (!isMobile) ...[
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.download_rounded,
                                color: Color(0xFF0C1935),
                              ),
                              tooltip: 'Export CSV (placeholder)',
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: _showReportsHistory,
                              icon: const Icon(
                                Icons.history,
                                color: Color(0xFF0C1935),
                              ),
                              tooltip: 'View Reports History',
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              onPressed: _submitToPM,
                              icon: const Icon(Icons.send),
                              label: const Text('Submit to PM'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          // notification bell
                          if (!isMobile)
                            Stack(
                              children: [
                                IconButton(
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Notifications opened (demo)',
                                          ),
                                        ),
                                      ),
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_outlined,
                                      color: Color(0xFF0C1935),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B6B),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (!isMobile) const SizedBox(width: 10),
                          // AESTRA account (hidden on mobile)
                          if (!isMobile)
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'switch') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Switch account (demo)'),
                                    ),
                                  );
                                } else if (value == 'logout') {
                                  await AuthService().logout();
                                  if (!context.mounted) return;
                                  context.go('/login');
                                }
                              },
                              offset: const Offset(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'switch',
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.swap_horiz,
                                            size: 18,
                                            color: Colors.black87,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Switch Account'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(height: 1),
                                    const PopupMenuItem<String>(
                                      value: 'logout',
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.logout,
                                            size: 18,
                                            color: Color(0xFFFF6B6B),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Logout',
                                            style: TextStyle(
                                              color: Color(0xFFFF6B6B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const SupervisorUserBadge(),
                              ),
                            ),
                          if (isMobile)
                            IconButton(
                              icon: Stack(
                                children: [
                                  const Icon(
                                    Icons.notifications_outlined,
                                    color: Color(0xFF0C1935),
                                    size: 22,
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B6B),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Notifications opened (demo)',
                                      ),
                                    ),
                                  ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // controls + KPIs (hidden on mobile)
                    if (!isMobile)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            // single date selector
                            Card(
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
                                  children: [
                                    TextButton.icon(
                                      onPressed: _pickReportDate,
                                      icon: const Icon(
                                        Icons.calendar_today,
                                        size: 18,
                                      ),
                                      label: Text(_dateFmt.format(_weekEnd)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  _kpiCard(
                                    'Total Hours',
                                    '${_totalHours.toStringAsFixed(1)}',
                                    icon: Icons.access_time,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 12),
                                  _kpiCard(
                                    'SSS',
                                    _money.format(_totalSSS),
                                    icon: Icons.shield,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 12),
                                  _kpiCard(
                                    'PhilHealth',
                                    _money.format(_totalPhilhealth),
                                    icon: Icons.health_and_safety,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  _kpiCard(
                                    'Pag-IBIG',
                                    _money.format(_totalPagibig),
                                    icon: Icons.home,
                                    color: Colors.lightBlue,
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                                  // Mobile compact list
                                  Expanded(
                                    child: _isLoading
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : _loadError != null
                                        ? Center(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
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
                                              'No attendance data up to selected date',
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

                                              return Card(
                                                margin: const EdgeInsets.only(
                                                  bottom: 12,
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
                                                          12,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        // Avatar
                                                        Container(
                                                          width: 48,
                                                          height: 48,
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
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
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
                                                                  fontSize: 15,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          3,
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
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        color: Colors
                                                                            .grey,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    '${r.totalHours.toStringAsFixed(1)} hrs',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: Colors
                                                                          .grey[600],
                                                                    ),
                                                                  ),
                                                                  if (r.overtimeHours >
                                                                      0) ...[
                                                                    const SizedBox(
                                                                      width: 6,
                                                                    ),
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: const Color(
                                                                          0xFFFF8F00,
                                                                        ).withOpacity(0.1),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              4,
                                                                            ),
                                                                      ),
                                                                      child: Text(
                                                                        '+${r.overtimeHours.toStringAsFixed(0)} OT',
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              10,
                                                                          color: Color(
                                                                            0xFFFF6F00,
                                                                          ),
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
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
                                                                r.computedSalary,
                                                              ),
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 16,
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
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        TextButton.icon(
                                                          onPressed: () =>
                                                              _showWorkerDetails(
                                                                r,
                                                              ),
                                                          icon: const Icon(
                                                            Icons.visibility,
                                                            size: 16,
                                                          ),
                                                          label: const Text(
                                                            'Summary',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                          style:
                                                              TextButton.styleFrom(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                minimumSize:
                                                                    Size.zero,
                                                                tapTargetSize:
                                                                    MaterialTapTargetSize
                                                                        .shrinkWrap,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                  // Mobile summary footer
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, -2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total Deductions',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              _money.format(_totalDeductions),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: Colors.redAccent,
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
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Total Net Salary',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
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
                                  const SizedBox(height: 8),
                                ],
                              )
                            : Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                        color: accent.withOpacity(0.05),
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
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Cash Adv. Deduct',
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
                                                'No attendance data up to selected date',
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
                                                              child: Text(
                                                                r.name,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 13,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
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
                                                              '${r.totalHours.toStringAsFixed(1)}',
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
                                                            if (r.overtimeHours >
                                                                0)
                                                              Text(
                                                                '+${r.overtimeHours.toStringAsFixed(1)} OT',
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
                                                                color: Colors
                                                                    .green,
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
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          _money.format(
                                                            r.deduction,
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
                                                            r.computedSalary,
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
                                                          alignment:
                                                              Alignment
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
                                                                    vertical:
                                                                        6,
                                                                  ),
                                                              side: BorderSide(
                                                                color: accent
                                                                    .withOpacity(
                                                                      0.5,
                                                                    ),
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
                                        color: accent.withOpacity(0.05),
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
                                                  color: Colors.green,
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
                _buildNavItem(Icons.list_alt, 'Logs', false),
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
              _buildMoreOption(
                Icons.show_chart,
                'Task Progress',
                'Tasks',
                false,
              ),
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
    final cashAdvanceController = TextEditingController(
      text: r.cashAdvance.toStringAsFixed(2),
    );
    final deductionController = TextEditingController(
      text: r.deduction.toStringAsFixed(2),
    );
    double editableCashAdvance = r.cashAdvance;
    double editableDeduction = r.deduction;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final liveTotalDeductions =
              r.totalGovernmentDeductions + editableDeduction;
          final liveNetSalary = r.grossPay - liveTotalDeductions;

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
                    color: accent.withOpacity(0.05),
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
                        '${r.totalHours.toStringAsFixed(1)}',
                        Icons.access_time,
                      ),
                      _detailItem(
                        'OT',
                        '${r.overtimeHours.toStringAsFixed(1)}',
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
                    'Summary period: ${_dateFmt.format(_weekStart)} to ${_dateFmt.format(_weekEnd)} (as of selected date)',
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                      TextField(
                        controller: cashAdvanceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Cash Advance Balance (PHP)',
                          prefixText: '₱ ',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = _toDouble(val);
                          setModalState(() {
                            editableCashAdvance = parsed < 0 ? 0 : parsed;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: deductionController,
                        keyboardType: const TextInputType.numberWithOptions(
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
                            editableDeduction = parsed < 0 ? 0 : parsed;
                          });
                        },
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
                                    await _updateWorkerCashAdvanceSettings(
                                      workerId: r.fieldWorkerId,
                                      cashAdvanceBalance: editableCashAdvance,
                                      deductionPerSalary: editableDeduction,
                                    );
                                    await _refreshReports();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Cash advance settings updated',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
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

                // Salary breakdown
                const Text(
                  'Salary Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                _salaryRow(
                  'Gross Pay',
                  _money.format(r.grossPay),
                  Colors.black,
                  isBold: true,
                ),
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
                  Colors.green,
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
                  '- ${_money.format(editableDeduction)}',
                  Colors.redAccent,
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
