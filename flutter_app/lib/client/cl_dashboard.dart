import 'package:flutter/material.dart';
import 'widgets/top_controls.dart';
import 'widgets/projects_grid.dart';
import 'models/project_item.dart';
import 'widgets/dashboard_header.dart';

class ClDashboardPage extends StatelessWidget {
	const ClDashboardPage({super.key});

	static final List<ProjectItem> _projects = [
		const ProjectItem(
			title: 'Super Highway',
			location: 'Divisoria, Zamboanga City',
			progress: 0.15,
			startDate: '08/20/2025',
			endDate: '08/20/2026',
			tasksCompleted: 8,
			totalTasks: 15,
			imageUrl:
					'https://images.unsplash.com/photo-1545259742-9e4f2baf2d4d?auto=format&fit=crop&w=800&q=60',
		),
		const ProjectItem(
			title: "Richmond's House",
			location: 'Sta. Maria, Zamboanga City',
			progress: 0.45,
			startDate: '08/20/2025',
			endDate: '08/20/2026',
			tasksCompleted: 8,
			totalTasks: 40,
			imageUrl:
					'https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=800&q=60',
		),
		const ProjectItem(
			title: 'Diversion Road',
			location: 'Luyahan, Zamboanga City',
			progress: 0.9,
			startDate: '08/20/2025',
			endDate: '10/25/2025',
			tasksCompleted: 40,
			totalTasks: 53,
			imageUrl:
					'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=800&q=60',
		),
	];

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: const Color(0xFFF4F6F9),
			body: Column(
				children: [
					const ClientDashboardHeader(title: 'Projects'),
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									const TopControls(),
									const SizedBox(height: 18),
									ProjectsGrid(items: _projects),
								],
							),
						),
					),
				],
			),
		);
	}
}
