import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  static final List<ProjectInventory> _projects = [
    ProjectInventory(
      name: 'Super Highway',
      code: 'PRJ-001',
      location: 'Divisoria, Zamboanga City',
      progress: 0.55,
      materials: [
        MaterialItem(name: 'Rebar Steel', category: 'Steel', quantity: 120, unit: 'tons', status: MaterialStatus.low),
        MaterialItem(name: 'Concrete Mix A', category: 'Concrete', quantity: 240, unit: 'bags', status: MaterialStatus.inStock),
        MaterialItem(name: 'Traffic Barriers', category: 'Equipment', quantity: 32, unit: 'sets', status: MaterialStatus.out),
      ],
    ),
    ProjectInventory(
      name: "Richmond's House",
      code: 'PRJ-014',
      location: 'Sta. Maria, Zamboanga City',
      progress: 0.30,
      materials: [
        MaterialItem(name: 'Ceramic Tiles', category: 'Finishing', quantity: 160, unit: 'boxes', status: MaterialStatus.inStock),
        MaterialItem(name: 'Plywood Boards', category: 'Lumber', quantity: 45, unit: 'sheets', status: MaterialStatus.low),
        MaterialItem(name: 'Electrical Wire', category: 'Electrical', quantity: 600, unit: 'meters', status: MaterialStatus.inStock),
      ],
    ),
    ProjectInventory(
      name: 'Diversion Road',
      code: 'PRJ-022',
      location: 'Luyahan, Zamboanga City',
      progress: 0.89,
      materials: [
        MaterialItem(name: 'Asphalt Mix', category: 'Road Works', quantity: 540, unit: 'tons', status: MaterialStatus.inStock),
        MaterialItem(name: 'Safety Cones', category: 'Safety', quantity: 220, unit: 'pcs', status: MaterialStatus.inStock),
        MaterialItem(name: 'Diesel Fuel', category: 'Fuel', quantity: 2.5, unit: 'kL', status: MaterialStatus.low),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Row(
        children: [
          const Sidebar(currentPage: 'Inventory'),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(title: 'Inventory'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _InventoryHeader(),
                        const SizedBox(height: 24),
                        _SummaryCards(projects: _projects),
                        const SizedBox(height: 24),
                        ..._projects.map(
                          (project) => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: ProjectInventoryCard(project: project),
                          ),
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

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Materials Inventory',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0C1935),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Track, order, and audit materials for every active project.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A18),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {},
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text(
              'Add Material',
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

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.projects});

  final List<ProjectInventory> projects;

  @override
  Widget build(BuildContext context) {
    final totalItems = projects.fold<int>(0, (sum, p) => sum + p.materials.length);
    final lowStock = projects.fold<int>(
      0,
      (sum, p) => sum + p.materials.where((m) => m.status == MaterialStatus.low).length,
    );
    final outStock = projects.fold<int>(
      0,
      (sum, p) => sum + p.materials.where((m) => m.status == MaterialStatus.out).length,
    );

    final cards = [
      _SummaryItem(label: 'Active Projects', value: projects.length, icon: Icons.domain_outlined),
      _SummaryItem(label: 'Materials Tracked', value: totalItems, icon: Icons.inventory_2_outlined),
      _SummaryItem(label: 'Low Stock', value: lowStock, icon: Icons.warning_amber_outlined, highlightColor: const Color(0xFFFFF5E6)),
      _SummaryItem(label: 'Out of Stock', value: outStock, icon: Icons.error_outline, highlightColor: const Color(0xFFFFEEF0)),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: cards
          .map(
            (card) => Container(
              width: 200,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card.highlightColor ?? Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(card.icon, color: const Color(0xFFFF7A18)),
                  const SizedBox(height: 14),
                  Text(
                    card.label,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.value.toString(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0C1935),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class ProjectInventoryCard extends StatelessWidget {
  const ProjectInventoryCard({super.key, required this.project});

  final ProjectInventory project;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${project.location}  •  ${project.code}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7A18),
                    side: const BorderSide(color: Color(0xFFFFE0D3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Add material',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: project.progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation(
              project.progress >= 0.8 ? const Color(0xFF22C55E) : const Color(0xFFFF7A18),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Progress ${(project.progress * 100).round()}%',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          _MaterialTable(materials: project.materials),
        ],
      ),
    );
  }
}

class _MaterialTable extends StatelessWidget {
  const _MaterialTable({required this.materials});

  final List<MaterialItem> materials;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Material', style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Text('Category', style: _tableHeaderStyle)),
                Expanded(child: Text('Qty', style: _tableHeaderStyle)),
                Expanded(child: Text('Unit', style: _tableHeaderStyle)),
                Expanded(child: Text('Status', style: _tableHeaderStyle)),
                SizedBox(width: 80, child: Text('Actions', style: _tableHeaderStyle)),
              ],
            ),
          ),
          ...materials.map(
            (material) => Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      material.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0C1935)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(material.category, style: const TextStyle(color: Color(0xFF6B7280))),
                  ),
                  Expanded(child: Text(material.quantity.toString(), style: const TextStyle(color: Color(0xFF0C1935)))),
                  Expanded(child: Text(material.unit, style: const TextStyle(color: Color(0xFF6B7280)))),
                  Expanded(child: _StatusChip(status: material.status)),
                  SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Color(0xFF2563EB)),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFF43F5E)),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MaterialStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case MaterialStatus.inStock:
        bg = const Color(0xFFE8F8F0);
        text = const Color(0xFF0F9D58);
        label = 'In Stock';
        break;
      case MaterialStatus.low:
        bg = const Color(0xFFFFF5E6);
        text = const Color(0xFFFF7A18);
        label = 'Low Stock';
        break;
      case MaterialStatus.out:
        bg = const Color(0xFFFFEEF0);
        text = const Color(0xFFE11D48);
        label = 'Out';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

class _SummaryItem {
  _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    this.highlightColor,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color? highlightColor;
}

class ProjectInventory {
  const ProjectInventory({
    required this.name,
    required this.code,
    required this.location,
    required this.progress,
    required this.materials,
  });

  final String name;
  final String code;
  final String location;
  final double progress;
  final List<MaterialItem> materials;
}

class MaterialItem {
  const MaterialItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.status,
  });

  final String name;
  final String category;
  final num quantity;
  final String unit;
  final MaterialStatus status;
}

enum MaterialStatus { inStock, low, out }

const TextStyle _tableHeaderStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF94A3B8),
  letterSpacing: 0.5,
);
