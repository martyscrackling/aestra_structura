import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/login.dart';
import 'auth/signup.dart';
import 'auth/infos.dart';
import 'projectmanager/dashboard_page.dart';
import 'projectmanager/projects_page.dart';
import 'projectmanager/workforce_page.dart';
import 'projectmanager/clients_page.dart';
import 'projectmanager/reports_page.dart';
import 'projectmanager/inventory_page.dart';
import 'projectmanager/settings_page.dart';
import 'supervisor/dashboard_page.dart' as supervisor;
import 'client/cl_dashboard.dart' as client;
import 'license/plan.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'xxx',
    anonKey: 'xxx',
    debug: true, // optional
  );

  setUrlStrategy(PathUrlStrategy());

  // Initialize auth ONCE before app starts
  final authService = AuthService();
  await authService.initializeAuth();

  runApp(const StructuraApp());
}

class StructuraApp extends StatelessWidget {
  const StructuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
          name: 'home',
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
          name: 'login',
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignUpPage(),
          name: 'signup',
        ),
        GoRoute(
          path: '/infos',
          builder: (context, state) => const InfosPage(),
          name: 'infos',
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const PMDashboardPage(),
          name: 'dashboard',
        ),
        GoRoute(
          path: '/license',
          builder: (context, state) => const LicenseActivationPage(),
          name: 'license',
        ),
        GoRoute(
          path: '/projects',
          builder: (context, state) => const ProjectsPage(),
          name: 'projects',
        ),
        GoRoute(
          path: '/workforce',
          builder: (context, state) => const WorkforcePage(),
          name: 'workforce',
        ),
        GoRoute(
          path: '/clients',
          builder: (context, state) => const ClientsPage(),
          name: 'clients',
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => ReportsPage(),
          name: 'reports',
        ),
        GoRoute(
          path: '/inventory',
          builder: (context, state) => InventoryPage(),
          name: 'inventory',
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => SettingsPage(),
          name: 'settings',
        ),
        GoRoute(
          path: '/supervisor',
          builder: (context, state) =>
              const supervisor.SupervisorDashboardPage(),
          name: 'supervisor',
        ),
        GoRoute(
          path: '/client',
          builder: (context, state) =>
              const client.ClDashboardPage(),
          name: 'client',
        ),
      ],
    );

    return ChangeNotifierProvider(
      create: (context) {
        final authService = AuthService();
        authService.initializeAuth();
        return authService;
      },
      child: MaterialApp.router(
        title: 'Structura',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    );
  }
}

// -------------------- HOME PAGE --------------------
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Column(
          children: const [
            Navbar(),
            HeroSection(),
            SizedBox(height: 40),
            WhyChooseSection(),
            SizedBox(height: 40),
            ProjectTrackingSection(),
            SizedBox(height: 40),
            FooterSection(),
          ],
        ),
      ),
    );
  }
}

// -------------------- NAVBAR --------------------
class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  bool _isMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return SafeArea(
      child: Container(
        color: const Color(0xFF0B1534),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 40,
          vertical: 20,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: isMobile
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/structuralogo.png',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Structura',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                if (!isMobile)
                  Row(
                    children: [
                      _navItem('Home'),
                      _navItem('Features'),
                      _navItem('Projects'),
                      _navItem('Contact Us'),
                      const SizedBox(width: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A1F),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Get Started',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  )
                else
                  IconButton(
                    icon: Icon(
                      _isMenuOpen ? Icons.close : Icons.menu,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        _isMenuOpen = !_isMenuOpen;
                      });
                    },
                  ),
              ],
            ),
            if (isMobile && _isMenuOpen)
              Column(
                children: [
                  const SizedBox(height: 16),
                  _navItem('Home', center: true),
                  _navItem('Features', center: true),
                  _navItem('Projects', center: true),
                  _navItem('Contact Us', center: true),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A1F),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Get Started',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String text, {bool center = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        textAlign: center ? TextAlign.center : TextAlign.start,
      ),
    );
  }
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();

    // Wait 3 seconds before showing homepage
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/structura_logo.png', height: 100),
            const SizedBox(height: 20),
            const Text(
              'Loading Structura...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 25),
            const CircularProgressIndicator(
              color: Color(0xFF0B1534),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- HERO SECTION --------------------
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Stack(
      children: [
        Container(
          height: isMobile ? 420 : 500,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/hero_bg.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          height: isMobile ? 420 : 500,
          color: Colors.black.withOpacity(0.5),
        ),
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: isMobile
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'For architects • engineers • project managers',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'All-in-one platform to track projects, logs, and workers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 29 : 30,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Structura centralizes communication, workforce tracking, and reporting so firms deliver projects on time and within budget.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 14 : 16,
                      height: 1.5,
                    ),
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                  ),
                  const SizedBox(height: 65),

                  // Action buttons
                  _buildActionButtons(context: context, isMobile: isMobile),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons({
    required BuildContext context,
    required bool isMobile,
  }) {
    if (isMobile) {
      // Mobile: side by side, swapped order
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'See Features',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A1F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Desktop: side by side, swapped order
      return Row(
        children: [
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'See Features',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A1F),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Get Started',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
  }
}

// -------------------- WHY CHOOSE SECTION --------------------
class WhyChooseSection extends StatelessWidget {
  const WhyChooseSection({super.key});

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40),
      child: Column(
        crossAxisAlignment: isMobile
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          const Text(
            'Why Choose Structura?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B1534),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Wrap(
            alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
            spacing: 20,
            runSpacing: 20,
            children: const [
              FeatureCard(
                title: 'Multi-project Dashboard',
                description:
                    'Manage multiple projects in one place, with clear insights and progress tracking.',
              ),
              FeatureCard(
                title: 'Worker & Material Tracking',
                description:
                    'Track crew assignments, attendance, and resource usage efficiently.',
              ),
              FeatureCard(
                title: 'AI-based Recommendations',
                description:
                    'Get suggestions for optimal crew allocation and project management decisions.',
              ),
              FeatureCard(
                title: 'Data Security',
                description:
                    'All your project data is stored securely with full encryption and backup.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFF5A1F),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// -------------------- PROJECT TRACKING SECTION --------------------
class ProjectTrackingSection extends StatelessWidget {
  const ProjectTrackingSection({super.key});

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 20 : 40),
      child: Column(
        crossAxisAlignment: isMobile
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (!isMobile)
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/engineer.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(child: _buildTextSection(isMobile)),
              ],
            )
          else
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/engineer.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextSection(isMobile),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTextSection(bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        const Text(
          "Track every project with clarity",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B1437),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "From planning to handover, Structura gives you end-to-end visibility of progress, resources, and costs.",
          style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "Activate license now!",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------- FOOTER SECTION --------------------
class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      color: const Color(0xFF0B1534),
      padding: EdgeInsets.symmetric(
        vertical: 40,
        horizontal: isMobile ? 20 : 60,
      ),
      child: Column(
        crossAxisAlignment: isMobile
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (!isMobile)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _footerColumns(),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [..._footerColumns()],
            ),
          const SizedBox(height: 40),
          const Divider(color: Colors.white24),
          const SizedBox(height: 20),
          const Text(
            '© 2025 Structura. All Rights Reserved.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  List<Widget> _footerColumns() {
    return [
      // Logo and Description
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/structuralogo.png',
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 10),
              const Text(
                'Structura',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(
            width: 280,
            child: Text(
              'Empowering engineers and project managers with tools for smarter, faster construction project tracking.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 30),

      // Quick Links
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Quick Links',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 10),
          Text('Home', style: TextStyle(color: Colors.white70)),
          Text('Features', style: TextStyle(color: Colors.white70)),
          Text('Projects', style: TextStyle(color: Colors.white70)),
          Text('Contact', style: TextStyle(color: Colors.white70)),
        ],
      ),

      const SizedBox(height: 30),

      // Contact Info
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Contact Us',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 10),
          Text('structura@gmail.com', style: TextStyle(color: Colors.white70)),
          Text('+63 912 345 6789', style: TextStyle(color: Colors.white70)),
          Text('Zamboanga City, PH', style: TextStyle(color: Colors.white70)),
        ],
      ),
    ];
  }
}

// -------------------- FEATURES PAGE --------------------
class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Features"),
        backgroundColor: const Color(0xFF0B1534),
      ),
      body: const Center(
        child: Text(
          "Welcome to the Features Page!!",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
