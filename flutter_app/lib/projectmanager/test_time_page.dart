import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'widgets/responsive_page_layout.dart';
import '../services/app_time_service.dart';

class PMTestTimePage extends StatefulWidget {
  const PMTestTimePage({super.key});

  @override
  State<PMTestTimePage> createState() => _PMTestTimePageState();
}

class _PMTestTimePageState extends State<PMTestTimePage> {
  final Color accent = const Color(0xFFFF7A18);
  final DateFormat _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  DateTime _pickedDateTime = AppTimeService.now();

  @override
  void initState() {
    super.initState();
    final existing = AppTimeService.overrideNow;
    if (existing != null) {
      _pickedDateTime = existing;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _pickedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _pickedDateTime.hour,
        _pickedDateTime.minute,
        _pickedDateTime.second,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _pickedDateTime.hour,
        minute: _pickedDateTime.minute,
      ),
    );
    if (picked == null) return;

    setState(() {
      _pickedDateTime = DateTime(
        _pickedDateTime.year,
        _pickedDateTime.month,
        _pickedDateTime.day,
        picked.hour,
        picked.minute,
        0,
      );
    });
  }

  Future<void> _applyOverride() async {
    await AppTimeService.setOverride(_pickedDateTime);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Test time set to ${_fmt.format(_pickedDateTime)}')),
    );
  }

  Future<void> _clearOverride() async {
    await AppTimeService.clearOverride();
    if (!mounted) return;
    setState(() {
      _pickedDateTime = AppTimeService.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test time cleared. Using device time.')),
    );
  }

  Widget _infoRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePageLayout(
      currentPage: 'Test Time',
      title: 'Test Date & Time',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ValueListenableBuilder<DateTime?>(
                valueListenable: AppTimeService.overrideNotifier,
                builder: (context, activeOverride, _) {
                  final effectiveNow = AppTimeService.now();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Testing Clock Controls',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0C1935),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set app date/time for testing workflows across PM and Supervisor.',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _infoRow(
                        label: 'Current effective time',
                        value: _fmt.format(effectiveNow),
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        label: 'Active override',
                        value: activeOverride == null
                            ? 'None (device clock)'
                            : _fmt.format(activeOverride),
                      ),
                      const SizedBox(height: 20),
                      _infoRow(
                        label: 'Selected test value',
                        value: _fmt.format(_pickedDateTime),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Pick Date'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time),
                            label: const Text('Pick Time'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _applyOverride,
                            icon: const Icon(Icons.save),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                            ),
                            label: const Text('Apply Test Time'),
                          ),
                          TextButton.icon(
                            onPressed: _clearOverride,
                            icon: const Icon(Icons.restore),
                            label: const Text('Reset to Device Time'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
