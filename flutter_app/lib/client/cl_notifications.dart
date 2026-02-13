import 'package:flutter/material.dart';
import '../services/client_dashboard_service.dart';

class ClNotificationsPage extends StatelessWidget {
  const ClNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final service = ClientDashboardService();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Color(0xFF0C1935)),
        ),
      ),
      body: FutureBuilder<ClientNotificationsPayload>(
        future: service.fetchClientNotifications(previewLimit: 20),
        builder: (context, snapshot) {
          final items =
              snapshot.data?.items ?? const <ClientNotificationItem>[];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load notifications.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No notifications.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            itemBuilder: (context, index) {
              final n = items[index];
              return ListTile(
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(n.title),
                subtitle: Text(n.time),
              );
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}
