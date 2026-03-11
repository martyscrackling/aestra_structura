import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/active_project.dart';

class AllProjectsPage extends StatefulWidget {
	final bool initialSidebarVisible;

	const AllProjectsPage({
		super.key,
		this.initialSidebarVisible = false,
	});

	@override
	State<AllProjectsPage> createState() => _AllProjectsPageState();
}

class _AllProjectsPageState extends State<AllProjectsPage> {
	final GlobalKey _activeProjectKey = GlobalKey();

	Widget _buildMobileLayout() {
		return SingleChildScrollView(
			padding: const EdgeInsets.all(12),
			child: ActiveProject(key: _activeProjectKey),
		);
	}

	Widget _buildTabletLayout() {
		return SingleChildScrollView(
			padding: const EdgeInsets.all(20),
			child: ActiveProject(key: _activeProjectKey),
		);
	}

	Widget _buildDesktopLayout() {
		return SingleChildScrollView(
			padding: const EdgeInsets.all(24),
			child: ActiveProject(key: _activeProjectKey),
		);
	}

	@override
	Widget build(BuildContext context) {
		final screenWidth = MediaQuery.of(context).size.width;
		final isDesktop = screenWidth > 1024;
		final isTablet = screenWidth > 600 && screenWidth <= 1024;
		final isMobile = screenWidth <= 600;

		return Scaffold(
			backgroundColor: const Color(0xFFF4F6F9),
			body: Stack(
				children: [
					Row(
						children: [
							if (isDesktop) Sidebar(activePage: 'Projects', keepVisible: true),
							Expanded(
								child: Column(
									children: [
										DashboardHeader(onMenuPressed: () {}),
										Expanded(
											child: isMobile
													? _buildMobileLayout()
													: isTablet
													? _buildTabletLayout()
													: _buildDesktopLayout(),
										),
									],
								),
							),
						],
					),
				],
			),
		);
	}
}
