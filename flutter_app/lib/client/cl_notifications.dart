import 'package:flutter/material.dart';

class ClNotificationsPage extends StatelessWidget {
  const ClNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {'title': 'Progress update: Super Highway', 'time': '3 mins ago'},
      {'title': 'Report approved: Diversion Road', 'time': '1 hr ago'},
      {'title': 'New invoice available', 'time': 'Yesterday'},
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Notifications', style: TextStyle(color: Color(0xFF0C1935))),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final n = notifications[index];
          return ListTile(
            leading: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
            title: Text(n['title']!),
            subtitle: Text(n['time']!),
          );
        },
        separatorBuilder: (_, __) => const Divider(),
        itemCount: notifications.length,
      ),
    );
  }
}
