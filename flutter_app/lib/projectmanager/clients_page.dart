import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/responsive_page_layout.dart';
import 'modals/add_client_modal.dart';
import 'client_profile_page.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  late Future<List<ClientInfo>> _clientsFuture;
  String _searchQuery = '';

  String _resolvePhotoUrl(dynamic rawPhoto) {
    final photo = (rawPhoto?.toString() ?? '').trim();
    if (photo.isEmpty) return '';
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return photo;
    }

    // AppConfig.apiBaseUrl includes `/api/`; media is served from the same origin under `/media/`.
    final apiBase = Uri.parse(AppConfig.apiBaseUrl);
    final origin = apiBase.origin;
    if (photo.startsWith('/')) {
      return '$origin$photo';
    }
    return '$origin/$photo';
  }

  @override
  void initState() {
    super.initState();
    _clientsFuture = _fetchClients();
  }

  List<ClientInfo> _filterClients(List<ClientInfo> clients) {
    if (_searchQuery.isEmpty) return clients;
    final query = _searchQuery.toLowerCase();
    return clients.where((client) {
      return client.name.toLowerCase().contains(query) ||
          client.email.toLowerCase().contains(query) ||
          client.phone.toLowerCase().contains(query);
    }).toList();
  }

  Future<List<ClientInfo>> _fetchClients() async {
    try {
      final userId = AuthService().currentUser?['user_id'];
      if (userId == null) {
        return [];
      }

      final response = await http.get(
        AppConfig.apiUri('clients/?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((client) {
          final photoUrl = _resolvePhotoUrl(client['photo']);
          return ClientInfo(
            id: client['client_id'],
            name: '${client['first_name']} ${client['last_name']}',
            company: '',
            email: client['email'],
            phone: client['phone_number'],
            location: 'Philippines',
            avatarUrl: photoUrl,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return ResponsivePageLayout(
      currentPage: 'Clients',
      title: 'Clients',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClientsHeader(
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            onClientAdded: () {
              setState(() {
                _clientsFuture = _fetchClients();
              });
            },
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<ClientInfo>>(
            future: _clientsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No clients found'));
              } else {
                final filteredClients = _filterClients(snapshot.data!);
                return _ActiveClientsSection(clients: filteredClients);
              }
            },
          ),
          SizedBox(height: isMobile ? 80 : 0), // Space for bottom navbar
        ],
      ),
    );
  }
}

class _ClientsHeader extends StatelessWidget {
  final Function(String) onSearchChanged;
  final VoidCallback onClientAdded;

  const _ClientsHeader({
    required this.onSearchChanged,
    required this.onClientAdded,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 40,
                child: _AddClientButton(onClientAdded: onClientAdded),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 36,
                width: 200,
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search clients...',
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
          const SizedBox(height: 18),
          const Text(
            'All Clients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
        ] else ...[
          const Text(
            'Clients',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1935),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 36,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search clients...',
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
                  borderSide: const BorderSide(
                    color: Color(0xFF0C1935),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: _AddClientButton(onClientAdded: onClientAdded),
          ),
        ],
      ],
    );
  }
}

class _AddClientButton extends StatelessWidget {
  const _AddClientButton({required this.onClientAdded});

  final VoidCallback onClientAdded;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const AddClientModal(),
        ).then((_) {
          onClientAdded();
        });
      },
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Add Client', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7A18)),
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
    final hasAvatar = info.avatarUrl.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: isMobile ? 24 : 28,
                backgroundImage: hasAvatar
                    ? NetworkImage(info.avatarUrl)
                    : null,
                backgroundColor: Colors.grey[200],
                child: hasAvatar
                    ? null
                    : Icon(
                        Icons.person_outline,
                        color: Colors.grey[500],
                        size: 28,
                      ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0C1935),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    if (info.company.trim().isNotEmpty) ...[
                      Text(
                        info.company,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF7A18),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                    ],
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            info.location,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 11,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            info.email,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.phone,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7A18),
                    side: const BorderSide(color: Color(0xFFFFE0D3)),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ClientProfilePage(client: info),
                        transitionDuration: Duration.zero,
                      ),
                    );
                  },
                  child: Text(
                    isMobile ? 'View' : 'View profile',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
