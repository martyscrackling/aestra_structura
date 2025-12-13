import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'modals/add_client_modal.dart';
import 'client_profile_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  late Future<List<ClientInfo>> _clientsFuture;

  @override
  void initState() {
    super.initState();
    _clientsFuture = _fetchClients();
  }

  Future<List<ClientInfo>> _fetchClients() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/clients/'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((client) {
          return ClientInfo(
            id: client['client_id'],
            name: '${client['first_name']} ${client['last_name']}',
            company: 'AESTRA Build Corp.',
            email: client['email'],
            phone: client['phone_number'],
            location: 'Philippines',
            avatarUrl: 'https://randomuser.me/api/portraits/men/1.jpg',
          );
        }).toList();
      } else {
        throw Exception('Failed to load clients');
      }
    } catch (e) {
      print('Error fetching clients: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Clients'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Clients'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ClientsHeader(),
                        const SizedBox(height: 24),
                        FutureBuilder<List<ClientInfo>>(
                          future: _clientsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            } else if (!snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              return const Center(
                                child: Text('No clients found'),
                              );
                            } else {
                              return _ActiveClientsSection(
                                clients: snapshot.data!,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Clients',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0C1935),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Stay in touch with every partner and account.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A18),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AddClientModal(),
              );
            },
            icon: const Icon(Icons.add, size: 18, color: Colors.black),
            label: const Text(
              'Add Client',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveClientsSection extends StatelessWidget {
  const _ActiveClientsSection({required this.clients});

  final List<ClientInfo> clients;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Clients',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C1935),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth > 1300
                ? 4
                : constraints.maxWidth > 1000
                ? 3
                : constraints.maxWidth > 700
                ? 2
                : 1;
            final cardWidth =
                (constraints.maxWidth - (columnCount - 1) * 16) / columnCount;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: clients
                  .map(
                    (client) => SizedBox(
                      width: cardWidth,
                      child: ClientCard(info: client),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class ClientCard extends StatelessWidget {
  const ClientCard({super.key, required this.info});

  final ClientInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: NetworkImage(info.avatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    Text(
                      info.company,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Color(0xFFFF7A18),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.email_outlined,
                size: 16,
                color: Color(0xFFFF7A18),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                size: 16,
                color: Color(0xFFFF7A18),
              ),
              const SizedBox(width: 6),
              Text(
                info.phone,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          ClientProfilePage(client: info),
                      transitionDuration: Duration.zero,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7A18),
                  side: const BorderSide(color: Color(0xFFFFE0D3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'View profile',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ClientInfo {
  const ClientInfo({
    this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.location,
    required this.avatarUrl,
  });

  final int? id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String location;
  final String avatarUrl;
}
