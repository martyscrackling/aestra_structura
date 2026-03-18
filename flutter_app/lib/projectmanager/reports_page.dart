import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/responsive_page_layout.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

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

class ReportsPage extends StatefulWidget {
  ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Color neutral = const Color(0xFFF4F6F9);
  final Color accent = const Color(0xFFFF7A18);
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  DateTime _weekStart = DateTime.now();
  DateTime _weekEnd = DateTime.now();
  List<Map<String, dynamic>> _submittedReports = [];
  int _selectedReportIndex = -1;

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

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _readText(Map<String, dynamic> map, List<String> keys, String fallback) {
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
            deduction:
                double.tryParse((m['deduction'] ?? '0').toString()) ?? 0,
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final collected = <Map<String, dynamic>>[];

      final latestRaw = prefs.getString('pm_latest_report_v1');
      if (latestRaw != null && latestRaw.isNotEmpty) {
        final decodedLatest = jsonDecode(latestRaw);
        if (decodedLatest is Map) {
          collected.add(Map<String, dynamic>.from(decodedLatest));
        }
      }

      final raw = prefs.getString('supervisor_submitted_reports_v1');
      final decoded =
          (raw == null || raw.isEmpty) ? const [] : jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            collected.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final report in collected) {
        final key = '${report['submission_id'] ?? ''}|${report['submitted_at'] ?? ''}';
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

      if (!mounted) return;
      setState(() {
        _submittedReports = unique;
        _selectedReportIndex = unique.isEmpty ? -1 : 0;
      });

      if (unique.isNotEmpty) {
        _applySubmission(unique.first);
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
    final projectLabel = _readText(
      report,
      const ['project_name'],
      projectId == null ? 'Unknown Project' : 'Project #$projectId',
    );
    final supervisorLabel = _readText(
      report,
      const ['supervisor_name'],
      'Unknown Supervisor',
    );
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
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$submittedText • $totalWorkers workers',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
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

  // Submit the current report to PM (demo)
  void _submitToPM() {
    setState(() {
      _rows = List<AttendanceReport>.from(_rows);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitted successfully (demo)')),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final selectedReport =
      (_selectedReportIndex >= 0 && _selectedReportIndex < _submittedReports.length)
      ? _submittedReports[_selectedReportIndex]
      : null;
    final selectedProjectId =
      selectedReport == null ? null : _toInt(selectedReport['project_id']);
    final selectedProjectLabel = selectedReport == null
      ? 'No selected report'
      : _readText(
        selectedReport,
        const ['project_name'],
        selectedProjectId == null ? 'Unknown Project' : 'Project #$selectedProjectId',
        );
    final selectedSupervisorLabel = selectedReport == null
      ? 'Select a submission below'
      : _readText(
        selectedReport,
        const ['supervisor_name'],
        'Unknown Supervisor',
        );

    return ResponsivePageLayout(
      currentPage: 'Reports',
      title: 'Reports',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Subtitle and action buttons
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _submitToPM,
                              icon: const Icon(Icons.send, color: Colors.white, size: 18),
                              label: const Text(
                                'Submit',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.download_rounded,
                              color: Color(0xFF0C1935),
                            ),
                            tooltip: 'Export CSV',
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Column(
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
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Color(0xFF0C1935),
                        ),
                        tooltip: 'Export CSV',
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: _submitToPM,
                        icon: const Icon(Icons.send, color: Colors.white),
                        label: const Text(
                          'Submit',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submitted Reports',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1935),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_submittedReports.isEmpty)
                          Text(
                            'No supervisor submissions yet.',
                            style: TextStyle(color: Colors.grey[700]),
                          )
                        else
                          ...List.generate(_submittedReports.length, (index) {
                            final report = _submittedReports[index];
                            return _submissionCard(
                              report: report,
                              isSelected: index == _selectedReportIndex,
                              onTap: () {
                                setState(() {
                                  _selectedReportIndex = index;
                                });
                                _applySubmission(report);
                              },
                            );
                          }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Date selector
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
                            style: TextStyle(fontSize: isMobile ? 12 : 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // KPI Cards
                if (isMobile)
                  Column(
                    children: [
                      _kpiCard(
                        'Total Hours',
                        '${_totalHours.toStringAsFixed(1)}',
                        icon: Icons.access_time,
                        color: accent,
                      ),
                      const SizedBox(height: 8),
                      _kpiCard(
                        'Overtime',
                        '${_totalOvertime.toStringAsFixed(1)} hrs',
                        icon: Icons.flash_on,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      _kpiCard(
                        'Total Deductions',
                        _money.format(_totalDeductions),
                        icon: Icons.money_off,
                        color: Colors.redAccent,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          'Total Hours',
                          '${_totalHours.toStringAsFixed(1)}',
                          icon: Icons.access_time,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiCard(
                          'Overtime',
                          '${_totalOvertime.toStringAsFixed(1)} hrs',
                          icon: Icons.flash_on,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiCard(
                          'Total Deductions',
                          _money.format(_totalDeductions),
                          icon: Icons.money_off,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Worker List
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 8,
            ),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 10 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isMobile)
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Worker',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 220,
                            child: Text(
                              'Computed Salary',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!isMobile) const Divider(),
                    _rows.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'No data for selected week',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _rows.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, i) => _rowCard(_rows[i]),
                          ),
                    const SizedBox(height: 12),
                    // Totals summary
                    Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Deductions',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
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
                                const SizedBox(height: 12),
                                Text(
                                  'Total Computed Salary',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _money.format(_totalComputedSalary),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Deductions',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _money.format(_totalDeductions),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total Computed Salary',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _money.format(_totalComputedSalary),
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

          SizedBox(height: isMobile ? 80 : 12),
        ],
      ),
    );
  }
}
