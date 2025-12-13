import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'package:intl/intl.dart';

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

  double get grossPay => totalHours * hourlyRate + overtimeHours * hourlyRate * 1.5;
  double get computedSalary => (grossPay - cashAdvance - deduction);
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Color neutral = const Color(0xFFF4F6F9);
  final Color accent = const Color(0xFF1396E9);
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  DateTime _weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  DateTime _weekEnd = DateTime.now().add(Duration(days: DateTime.sunday - DateTime.now().weekday));

  // sample data (UI/layout only - no backend)
  List<AttendanceReport> _rows = [
    AttendanceReport(name: 'John Doe', role: 'Foreman', totalDaysPresent: 6, totalHours: 48, overtimeHours: 4, cashAdvance: 50.0, deduction: 0.0, hourlyRate: 8.0),
    AttendanceReport(name: 'Jane Smith', role: 'Carpenter', totalDaysPresent: 5, totalHours: 40, overtimeHours: 2, cashAdvance: 0.0, deduction: 10.0, hourlyRate: 7.5),
    AttendanceReport(name: 'Carlos Reyes', role: 'Laborer', totalDaysPresent: 6, totalHours: 52, overtimeHours: 6, cashAdvance: 20.0, deduction: 5.0, hourlyRate: 6.0),
  ];

  final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

 
  // Submit the current report to PM (demo)
  void _submitToPM() {
    setState(() {
      _rows = List<AttendanceReport>.from(_rows);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted to PM (demo)')));
  }

  double get _totalDeductions => _rows.fold(0.0, (t, r) => t + r.deduction + r.cashAdvance);
  double get _totalComputedSalary => _rows.fold(0.0, (t, r) => t + r.computedSalary);
  double get _totalOvertime => _rows.fold(0.0, (t, r) => t + r.overtimeHours);
  double get _totalHours => _rows.fold(0.0, (t, r) => t + r.totalHours);

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(context: context, initialDate: _weekStart, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) {
      setState(() {
        _weekStart = d;
        _weekEnd = _weekStart.add(const Duration(days: 6));
      });
    }
  }

  Future<void> _pickEndDate() async {
    final d = await showDatePicker(context: context, initialDate: _weekEnd, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) {
      setState(() {
        _weekEnd = d;
      });
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
                  decoration: BoxDecoration(color: (color ?? accent).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, color: color ?? accent, size: 20),
                ),
              if (icon != null) const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color ?? Colors.black)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowCard(AttendanceReport r) {
    final initials = r.name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join();
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
            CircleAvatar(backgroundColor: accent.withOpacity(0.14), child: Text(initials, style: TextStyle(color: accent, fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(r.role, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${r.totalDaysPresent} days', style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(width: 12),
                    Text('${r.totalHours.toStringAsFixed(1)} hrs', style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(width: 12),
                    if (r.overtimeHours > 0) Chip(label: Text('+${r.overtimeHours} OT'), backgroundColor: Colors.orange.withOpacity(0.12)),
                  ],
                ),
              ]),
            ),
            const SizedBox(width: 12),
            // show cash advance balance above computed salary and deduction
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Advance', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(cashAdvanceStr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.orange)),
              const SizedBox(height: 8),
              Text(salaryStr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.green)),
              const SizedBox(height: 6),
              Text('Deduct: $deductionStr', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutral,
      body: Row(
        children: [
          const Sidebar(activePage: 'Reports'),
          Expanded(
            child: Column(
              children: [
                // header with white background and slim blue line at left corner (keeps Notification bell & AESTRA)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    children: [
                      // slim blue accent line in the left corner
                      Container(width: 4, height: 56, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Weekly Attendance Report', style: TextStyle(color: Color(0xFF0C1935), fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Summary for ${_dateFmt.format(_weekStart)} — ${_dateFmt.format(_weekEnd)}', style: TextStyle(color: Colors.grey[700])),
                        ]),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.download_rounded, color: Color(0xFF0C1935)),
                        tooltip: 'Export CSV (placeholder)',
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: _submitToPM,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit to PM'),
                        style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      // notification bell
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications opened (demo)'))),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.notifications_outlined, color: Color(0xFF0C1935)),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(6))),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      // AESTRA account
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
                              const SizedBox(width: 10),
                              const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text("AESTRA", style: TextStyle(color: Color(0xFF0C1935), fontSize: 13, fontWeight: FontWeight.w700)), Text("Supervisor", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w400))]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // controls + KPIs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // date range selector
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: _pickStartDate,
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(_dateFmt.format(_weekStart)),
                              ),
                              const Text('—'),
                              TextButton.icon(
                                onPressed: _pickEndDate,
                                icon: const Icon(Icons.calendar_today, size: 18),
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
                            _kpiCard('Total Hours', '${_totalHours.toStringAsFixed(1)}', icon: Icons.access_time, color: accent),
                            const SizedBox(width: 12),
                            _kpiCard('Overtime', '${_totalOvertime.toStringAsFixed(1)} hrs', icon: Icons.flash_on, color: Colors.orange),
                            const SizedBox(width: 12),
                            _kpiCard('Total Deductions', _money.format(_totalDeductions), icon: Icons.money_off, color: Colors.redAccent),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // list of rows (card style)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(child: Text('Worker', style: TextStyle(fontWeight: FontWeight.w700))),
                                const SizedBox(width: 220, child: Text('Computed Salary', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
                              ],
                            ),
                            const Divider(),
                            Expanded(
                              child: _rows.isEmpty
                                  ? Center(child: Text('No data for selected week', style: TextStyle(color: Colors.grey[700])))
                                  : ListView.builder(
                                      itemCount: _rows.length,
                                      itemBuilder: (context, i) => _rowCard(_rows[i]),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            // totals summary
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Total Deductions', style: TextStyle(color: Colors.grey[700])),
                                    const SizedBox(height: 6),
                                    Text(_money.format(_totalDeductions), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.redAccent)),
                                  ]),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('Total Computed Salary', style: TextStyle(color: Colors.grey[700])),
                                    const SizedBox(height: 6),
                                    Text(_money.format(_totalComputedSalary), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
                                  ]),
                                ],
                              ),
                            )
                          ],
                        ),
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
    );
  }
}