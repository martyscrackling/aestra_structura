class ProjectItem {
  const ProjectItem({
    required this.projectId,
    required this.title,
    required this.location,
    required this.progress,
    required this.startDate,
    required this.endDate,
    required this.tasksCompleted,
    required this.totalTasks,
    required this.imageUrl,
  });

  final int projectId;
  final String title;
  final String location;
  final double progress;
  final String startDate;
  final String endDate;
  final int tasksCompleted;
  final int totalTasks;
  final String imageUrl;
}
