import 'package:flutter/material.dart';
import '../projectmanager/project_info.dart' as project_manager;
import 'widgets/sidebar.dart';
import 'widgets/dashboard_header.dart';

class ProjectInfosPage extends StatelessWidget {
	final String projectTitle;
	final String projectLocation;
	final String projectImage;
	final double progress;
	final String? budget;
	final int projectId;

	const ProjectInfosPage({
		super.key,
		required this.projectTitle,
		required this.projectLocation,
		required this.projectImage,
		required this.progress,
		this.budget,
		required this.projectId,
	});

	@override
	Widget build(BuildContext context) {
		final screenWidth = MediaQuery.of(context).size.width;
		final isDesktop = screenWidth > 1024;

		return Scaffold(
			backgroundColor: const Color(0xFFF4F6F9),
			body: Row(
				children: [
					if (isDesktop) const Sidebar(activePage: 'Projects', keepVisible: true),
					Expanded(
						child: Column(
							children: [
								DashboardHeader(onMenuPressed: () {}),
								Expanded(
									child: project_manager.ProjectDetailsPage(
										projectTitle: projectTitle,
										projectLocation: projectLocation,
										projectImage: projectImage,
										progress: progress,
										budget: budget,
										projectId: projectId,
										useResponsiveLayout: false,
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
