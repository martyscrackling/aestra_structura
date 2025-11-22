import 'package:flutter/material.dart';

void main() {
  runApp(const PMDashboardApp());
}

class PMDashboardApp extends StatelessWidget {
  const PMDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PM Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const PMDashboard(),
    );
  }
}

class PMDashboard extends StatelessWidget {
  const PMDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color.fromARGB(143, 255, 255, 255),
        backgroundColor: const Color(0xFF0B1534),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Projects'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Workforce'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Clients'),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart),
            label: 'Reports',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search_outlined),
                          color: Colors.black54,
                          onPressed: () {},
                        ),
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              color: Colors.black54,
                              onPressed: () {},
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.menu),
                          color: Colors.black54,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // Recent Projects Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Recent Projects',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'View All',
                      style: TextStyle(color: Colors.blue, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Project Cards
                ProjectCard(
                  title: 'Super Highway',
                  location: 'Divisoria, Zamboanga City',
                  progress: 0.55,
                  taskInfo: '8/15',
                  progressColor: Colors.lightGreenAccent,
                  avatars: [
                    'https://randomuser.me/api/portraits/women/44.jpg',
                    'https://randomuser.me/api/portraits/men/33.jpg',
                  ],
                  extraCount: 2,
                ),
                const SizedBox(height: 12),
                ProjectCard(
                  title: "Richmond's House",
                  location: 'Sta. Maria, Zamboanga City',
                  progress: 0.30,
                  taskInfo: '8/40',
                  progressColor: Colors.orangeAccent,
                  avatars: [
                    'https://randomuser.me/api/portraits/men/11.jpg',
                    'https://randomuser.me/api/portraits/women/22.jpg',
                  ],
                  extraCount: 3,
                ),
                const SizedBox(height: 30),

                // Active Workers Header
                const Text(
                  'Active Workers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 15),

                // Active Workers Grid
                
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 15,
                  childAspectRatio: 1.7,
                  children: const [
                    WorkerCard(
                      icon: Icons.work_outline,
                      title: 'Mason',
                      titleStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                      count: 20,
                    ),
                    WorkerCard(
                      icon: Icons.design_services_outlined,
                      title: 'Architects',
                      count: 32,
                    ),
                    WorkerCard(
                      icon: Icons.engineering_outlined,
                      title: 'Engineers',
                      count: 32,
                    ),
                    WorkerCard(
                      icon: Icons.supervised_user_circle_outlined,
                      title: 'Supervisor',
                      count: 32,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  final String title;
  final String location;
  final double progress;
  final String taskInfo;
  final Color progressColor;
  final List<String> avatars;
  final int extraCount;

  const ProjectCard({
    super.key,
    required this.title,
    required this.location,
    required this.progress,
    required this.taskInfo,
    required this.progressColor,
    required this.avatars,
    required this.extraCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFD),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE5E9F2),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and options icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const Icon(Icons.more_horiz, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            location,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),

          // Progress bar with percent text
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Task info and avatars
          Row(
            children: [
              const Icon(
                Icons.check_box_outlined,
                size: 18,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(taskInfo, style: const TextStyle(color: Colors.grey)),
              const Spacer(),

              // Avatars stack
              SizedBox(
                width: 90,
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int i = 0; i < avatars.length; i++)
                      Positioned(
                        left: i * 28,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(avatars[i]),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                    Positioned(
                      left: avatars.length * 28,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade300,
                        child: Text(
                          '+$extraCount',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
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

class WorkerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final TextStyle? titleStyle;
  final double iconSize;

  const WorkerCard({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    this.titleStyle,
    this.iconSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFD),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE5E9F2),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 19, color: Colors.orange.shade700),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: titleStyle ?? const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
