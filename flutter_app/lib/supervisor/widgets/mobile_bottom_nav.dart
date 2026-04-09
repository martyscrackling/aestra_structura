import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_theme_tokens.dart';

enum SupervisorMobileTab { dashboard, projects, workers, more }

class SupervisorMobileBottomNav extends StatefulWidget {
  const SupervisorMobileBottomNav({
    super.key,
    required this.activeTab,
    required this.onSelect,
    this.activeMorePage,
  });

  final SupervisorMobileTab activeTab;
  final ValueChanged<String> onSelect;
  final String? activeMorePage;

  @override
  State<SupervisorMobileBottomNav> createState() =>
      _SupervisorMobileBottomNavState();
}

class _SupervisorMobileBottomNavState extends State<SupervisorMobileBottomNav> {
  bool _isMoreExpanded = false;

  @override
  void didUpdateWidget(covariant SupervisorMobileBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTab != SupervisorMobileTab.more && _isMoreExpanded) {
      setState(() {
        _isMoreExpanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: AppColors.navSurface),
        padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: _isMoreExpanded ? 58 : 0,
                child: _buildMoreHorizontalRail(context),
              ),
            ),
            if (_isMoreExpanded) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildNavItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    isActive: widget.activeTab == SupervisorMobileTab.dashboard,
                    onTap: () => widget.onSelect('Dashboard'),
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context,
                    icon: Icons.folder_open_rounded,
                    label: 'Projects',
                    isActive: widget.activeTab == SupervisorMobileTab.projects,
                    onTap: () => widget.onSelect('Projects'),
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context,
                    icon: Icons.groups_rounded,
                    label: 'Workers',
                    isActive: widget.activeTab == SupervisorMobileTab.workers,
                    onTap: () => widget.onSelect('Workers'),
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context,
                    icon: _isMoreExpanded
                        ? Icons.close_rounded
                        : Icons.grid_view_rounded,
                    label: _isMoreExpanded ? 'Close' : 'More',
                    isActive:
                        _isMoreExpanded ||
                        widget.activeTab == SupervisorMobileTab.more,
                    onTap: _toggleMore,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMore() {
    HapticFeedback.selectionClick();
    setState(() {
      _isMoreExpanded = !_isMoreExpanded;
    });
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final textColor = isActive
        ? const Color(0xFF4A9FD8) // Light blue for active
        : Colors.white.withOpacity(0.7);
    final bgColor = isActive ? Colors.white : Colors.transparent;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: isActive ? BorderRadius.circular(8) : BorderRadius.zero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreHorizontalRail(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: [
          _buildMoreChip(
            context,
            Icons.fact_check_rounded,
            'Attendance',
            'Attendance',
          ),
          _buildMoreChip(context, Icons.show_chart, 'Task Progress', 'Tasks'),
          _buildMoreChip(context, Icons.file_copy, 'Reports', 'Reports'),
          _buildMoreChip(context, Icons.inventory, 'Inventory', 'Inventory'),
        ],
      ),
    );
  }

  Widget _buildMoreChip(
    BuildContext context,
    IconData icon,
    String title,
    String page,
  ) {
    final isActive = widget.activeMorePage == page;
    final chipColor = isActive
        ? const Color(0xFF4A9FD8)
        : Colors.white; // Light blue for active

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSelect(page);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 118,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withOpacity(0.16)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? const Color(0xFF4A9FD8).withOpacity(0.45) // Light blue border
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: chipColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
