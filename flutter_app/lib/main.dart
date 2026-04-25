import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'auth/login.dart';
import 'auth/signup.dart';
import 'auth/infos.dart';
import 'auth/change_password.dart';
import 'projectmanager/dashboard_page.dart';
import 'projectmanager/projects_page.dart';
import 'projectmanager/workforce_page.dart';
import 'projectmanager/clients_page.dart';
import 'projectmanager/reports_page.dart';
import 'projectmanager/inventory_page.dart';
import 'projectmanager/settings_page.dart';
import 'projectmanager/notification_page.dart';
import 'projectmanager/audit_trail_page.dart';
import 'projectmanager/test_time_page.dart';
import 'supervisor/dashboard_page.dart' as supervisor;
import 'supervisor/all_projects.dart' as supervisor;
import 'supervisor/workers_management.dart' as supervisor;
import 'supervisor/attendance_page.dart' as supervisor;
import 'supervisor/reports.dart' as supervisor;
import 'supervisor/inventory.dart' as supervisor;
import 'supervisor/test_time_page.dart' as supervisor;
import 'supervisor/notification_inbox_page.dart';
import 'client/cl_dashboard.dart' as client;
import 'license/plan.dart';
import 'license/payment_status.dart';
import 'license/payment.dart';
import 'services/auth_service.dart';
import 'services/app_time_service.dart';
import 'services/app_theme_tokens.dart';
import 'services/url_strategy/url_strategy.dart';
import 'services/app_config.dart';

String _lastKnownValidPath = '/';
late SharedPreferences _appPrefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress harmless DevTools web warnings
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception.toString().contains('ext.flutter') ||
        details.exception.toString().contains('activeDevToolsServerAddress') ||
        details.exception.toString().contains('connectedVmServiceUri')) {
      return; // Suppress these harmless warnings
    }
    FlutterError.presentError(details);
  };

  await Supabase.initialize(
    url: 'https://prokngxytawscbszbnxc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByb2tuZ3h5dGF3c2Nic3pibnhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5OTU1NTcsImV4cCI6MjA3OTU3MTU1N30.ck9YleNWzRM6uMK7w33xfgp_4KmnCjpmVMWsA3aBc74',
    debug: true, // optional
  );

  configureUrlStrategy();
  await AppTimeService.initialize();
  _appPrefs = await SharedPreferences.getInstance();
  _lastKnownValidPath = _appPrefs.getString('last_known_valid_path') ?? '/';

  // Initialize auth ONCE before app starts
  final authService = AuthService();
  await authService.initializeAuth();

  runApp(const StructuraApp());
}

class StructuraApp extends StatelessWidget {
  const StructuraApp({super.key});

  CustomTransitionPage<void> _buildSmoothPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.015, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    const publicRoutes = <String>{
      '/',
      '/login',
      '/signup',
      '/infos',
      '/change-password',
    };

    final GoRouter router = GoRouter(
      initialLocation: '/',
      refreshListenable: authService,
      errorBuilder: (context, state) =>
          NotFoundPage(lastKnownPath: _lastKnownValidPath),
      redirect: (context, state) {
        final currentPath = state.uri.path;
        final loggedIn = authService.isLoggedIn;
        final isPublic = publicRoutes.contains(currentPath);
        final role = authService.currentUser?['role']?.toString() ?? '';
        final userHome = authService.homeRouteForRole(role);

        final isSupervisorRoute = currentPath == '/supervisor' ||
            currentPath.startsWith('/supervisor/');
        final isClientRoute =
            currentPath == '/client' || currentPath.startsWith('/client/');
        final isPmRoute = <String>{
          '/dashboard',
          '/license',
          '/projects',
          '/workforce',
          '/clients',
          '/reports',
          '/inventory',
          '/settings',
          '/notifications',
          '/audit-trail',
          '/test-time',
        }.contains(currentPath);
        final isSupervisorRole = role == 'Supervisor';
        final isClientRole = role == 'Client';
        final isPmRole = !isSupervisorRole && !isClientRole;
        final isKnownPath = isPublic ||
            isPmRoute ||
            isSupervisorRoute ||
            isClientRoute;

        if (isKnownPath) {
          _lastKnownValidPath = currentPath;
          _appPrefs.setString('last_known_valid_path', currentPath);
        }

        if (!loggedIn && !isPublic) {
          final encodedTarget = Uri.encodeComponent(currentPath);
          return '/login?redirectTo=$encodedTarget';
        }

        if (loggedIn && (currentPath == '/login' || currentPath == '/signup')) {
          return userHome;
        }

        // Enforce strict role-based access even when URL is changed manually.
        if (loggedIn) {
          if (isSupervisorRole && (isPmRoute || isClientRoute)) {
            return userHome;
          }
          if (isClientRole && (isPmRoute || isSupervisorRoute)) {
            return userHome;
          }
          if (isPmRole && (isSupervisorRoute || isClientRoute)) {
            return userHome;
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
          name: 'home',
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              LoginPage(redirectTo: state.uri.queryParameters['redirectTo']),
          name: 'login',
        ),
        GoRoute(
          path: '/change-password',
          name: 'change-password',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is! Map) {
              return const LoginPage();
            }
            final email = (extra['email'] ?? '') as String;
            final currentPassword = (extra['currentPassword'] ?? '') as String;
            final redirectTo = (extra['redirectTo'] ?? '/login') as String;
            if (email.isEmpty || currentPassword.isEmpty) {
              return const LoginPage();
            }
            return ChangePasswordPage(
              email: email,
              currentPassword: currentPassword,
              redirectTo: redirectTo,
            );
          },
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
          path: '/payment-success',
          builder: (context, state) {
            final userId = state.uri.queryParameters['user_id'];
            return PaymentSuccessPage(userId: userId);
          },
          name: 'payment-success',
        ),
        GoRoute(
          path: '/payment-failed',
          builder: (context, state) {
            final userId = state.uri.queryParameters['user_id'];
            return PaymentFailedPage(userId: userId);
          },
          name: 'payment-failed',
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
          path: '/notifications',
          builder: (context, state) => const NotificationPage(),
          name: 'notifications',
        ),
        GoRoute(
          path: '/audit-trail',
          builder: (context, state) => const AuditTrailPage(),
          name: 'audit-trail',
        ),
        GoRoute(
          path: '/test-time',
          builder: (context, state) => const PMTestTimePage(),
          name: 'test-time',
        ),
        GoRoute(
          path: '/supervisor',
          pageBuilder: (context, state) => _buildSmoothPage(
            state: state,
            child: const supervisor.SupervisorDashboardPage(),
          ),
          name: 'supervisor',
          routes: [
            GoRoute(
              path: 'projects',
              pageBuilder: (context, state) => _buildSmoothPage(
                state: state,
                child: const supervisor.AllProjectsPage(),
              ),
              name: 'supervisor-projects',
            ),
            GoRoute(
              path: 'workers',
              pageBuilder: (context, state) => _buildSmoothPage(
                state: state,
                child: const supervisor.WorkerManagementPage(),
              ),
              name: 'supervisor-workers',
            ),
            GoRoute(
              path: 'attendance',
              pageBuilder: (context, state) => _buildSmoothPage(
                state: state,
                child: const supervisor.AttendancePage(),
              ),
              name: 'supervisor-attendance',
            ),
            GoRoute(
              path: 'reports',
              pageBuilder: (context, state) => _buildSmoothPage(
                state: state,
                child: const supervisor.ReportsPage(),
              ),
              name: 'supervisor-reports',
            ),
            GoRoute(
              path: 'inventory',
              pageBuilder: (context, state) => _buildSmoothPage(
                state: state,
                child: const supervisor.InventoryPage(),
              ),
              name: 'supervisor-inventory',
            ),
            GoRoute(
              path: 'test-time',
              pageBuilder: (context, state) => _buildSmoothPage(
                state: state,
                child: const supervisor.TestTimePage(),
              ),
              name: 'supervisor-test-time',
            ),
            GoRoute(
              path: 'notifications',
              pageBuilder: (context, state) => _buildSmoothPage(
                state: state,
                child: const SupervisorNotificationPage(),
              ),
              name: 'supervisor-notifications',
            ),
          ],
        ),
        GoRoute(
          path: '/client',
          builder: (context, state) => const client.ClDashboardPage(),
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
        theme: AppTheme.light(),
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
                        onPressed: () => context.go('/login'),
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
                    onPressed: () => context.go('/login'),
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
              style:
                  OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ).copyWith(
                    backgroundColor: MaterialStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(MaterialState.hovered)) {
                        return Colors.white;
                      }
                      return Colors.transparent;
                    }),
                    foregroundColor: MaterialStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(MaterialState.hovered)) {
                        return const Color(0xFFFF5A1F);
                      }
                      return Colors.white;
                    }),
                  ),
              child: const Text('See Features'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.go('/login'),
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
            style:
                OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ).copyWith(
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) {
                      return Colors.white;
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) {
                      return const Color(0xFFFF5A1F);
                    }
                    return Colors.white;
                  }),
                ),
            child: const Text('See Features'),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: () => context.go('/login'),
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
            alignment: WrapAlignment.center,
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
class ProjectTrackingSection extends StatefulWidget {
  const ProjectTrackingSection({super.key});

  @override
  State<ProjectTrackingSection> createState() => _ProjectTrackingSectionState();
}

class _ProjectTrackingSectionState extends State<ProjectTrackingSection> {
  static const List<_SubscriptionPlanOption> _planOptions = [
    _SubscriptionPlanOption(
      years: 1,
      amountLabel: '₱5,000',
      subtitle: 'Billed annually',
      isPopular: false,
    ),
    _SubscriptionPlanOption(
      years: 3,
      amountLabel: '₱13,000',
      subtitle: 'Save 13% • Billed every 3 years',
      isPopular: true,
    ),
    _SubscriptionPlanOption(
      years: 5,
      amountLabel: '₱22,000',
      subtitle: 'Save 12% • Billed every 5 years',
      isPopular: false,
    ),
  ];

  Future<void> _showPlanSelectionModal(BuildContext context) async {
    final selectedPlan = await showDialog<_SubscriptionPlanOption>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.95, end: 1),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: Color(0xFFFF6F00),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Upgrade Your Plan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: Color(0xFF0A173D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a subscription plan to continue using all Premium features without interruption.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    ..._planOptions.map(
                      (plan) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(dialogContext).pop(plan),
                          child: Ink(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: plan.isPopular
                                    ? const Color(0xFFFF6F00)
                                    : Colors.grey.shade300,
                                width: plan.isPopular ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: plan.isPopular
                                  ? const Color(
                                      0xFFFF6F00,
                                    ).withValues(alpha: 0.05)
                                  : Colors.white,
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: plan.isPopular
                                          ? const Color(0xFFFF6F00)
                                          : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${plan.years} Year${plan.years > 1 ? 's' : ''}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0A173D),
                                            ),
                                          ),
                                          if (plan.isPopular) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF6F00),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'POPULAR',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        plan.subtitle,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  plan.amountLabel,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A173D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!context.mounted || selectedPlan == null) return;

    final isAuthenticated = await _ensureAuthenticatedForCheckout(context);
    if (!context.mounted || !isAuthenticated) return;

    await _showPaymentModal(context, selectedPlan);
  }

  Future<bool> _ensureAuthenticatedForCheckout(BuildContext context) async {
    // Product rule: always require explicit auth in modal before payment.
    final didAuthenticate = await _showInlineAuthModal(context);
    return didAuthenticate ?? false;
  }

  Future<bool?> _showInlineAuthModal(BuildContext context) async {
    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final loginEmailController = TextEditingController();
    final loginPasswordController = TextEditingController();
    final signupEmailController = TextEditingController();
    final signupPasswordController = TextEditingController();
    final signupConfirmController = TextEditingController();

    final currentEmail = (authService.currentUser?['email'] ?? '').toString();
    if (currentEmail.isNotEmpty) {
      loginEmailController.text = currentEmail;
      signupEmailController.text = currentEmail;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        bool isSignInMode = true;
        bool isSubmitting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE8EDF3)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33101C24),
                      blurRadius: 36,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sign In To Continue',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B1437),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Use your account before proceeding to payment.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Sign In'),
                            selected: isSignInMode,
                            selectedColor: const Color(0xFFFFEED9),
                            onSelected: (_) {
                              setModalState(() {
                                isSignInMode = true;
                                errorMessage = null;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Create Account'),
                            selected: !isSignInMode,
                            selectedColor: const Color(0xFFE8F3FF),
                            onSelected: (_) {
                              setModalState(() {
                                isSignInMode = false;
                                errorMessage = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: isSignInMode
                            ? Column(
                                key: const ValueKey('checkout-signin'),
                                children: [
                                  TextField(
                                    controller: loginEmailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _modalInputDecoration(
                                      'Email Address',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: loginPasswordController,
                                    obscureText: true,
                                    decoration: _modalInputDecoration(
                                      'Password',
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('checkout-signup'),
                                children: [
                                  TextField(
                                    controller: signupEmailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _modalInputDecoration(
                                      'Email Address',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: signupPasswordController,
                                    obscureText: true,
                                    decoration: _modalInputDecoration(
                                      'Create Password',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: signupConfirmController,
                                    obscureText: true,
                                    decoration: _modalInputDecoration(
                                      'Confirm Password',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(false),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setModalState(() {
                                      errorMessage = null;
                                      isSubmitting = true;
                                    });

                                    if (isSignInMode) {
                                      final email = loginEmailController.text
                                          .trim();
                                      final password = loginPasswordController
                                          .text
                                          .trim();
                                      if (email.isEmpty || password.isEmpty) {
                                        setModalState(() {
                                          errorMessage =
                                              'Please enter email and password.';
                                          isSubmitting = false;
                                        });
                                        return;
                                      }

                                      final success = await authService.login(
                                        email,
                                        password,
                                      );
                                      if (!context.mounted) return;
                                      if (!success) {
                                        setModalState(() {
                                          errorMessage =
                                              'Invalid credentials. Please try again.';
                                          isSubmitting = false;
                                        });
                                        return;
                                      }

                                      Navigator.of(dialogContext).pop(true);
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Signed in successfully. Continue to payment.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    final email = signupEmailController.text
                                        .trim();
                                    final password = signupPasswordController
                                        .text
                                        .trim();
                                    final confirm = signupConfirmController.text
                                        .trim();

                                    if (email.isEmpty ||
                                        password.isEmpty ||
                                        confirm.isEmpty) {
                                      setModalState(() {
                                        errorMessage =
                                            'Please complete all fields.';
                                        isSubmitting = false;
                                      });
                                      return;
                                    }

                                    if (password.length < 6) {
                                      setModalState(() {
                                        errorMessage =
                                            'Password must be at least 6 characters.';
                                        isSubmitting = false;
                                      });
                                      return;
                                    }

                                    if (password != confirm) {
                                      setModalState(() {
                                        errorMessage =
                                            'Passwords do not match.';
                                        isSubmitting = false;
                                      });
                                      return;
                                    }

                                    final success = await authService.signup(
                                      email,
                                      password,
                                      'User',
                                      'Account',
                                    );
                                    if (!context.mounted) return;

                                    if (!success) {
                                      setModalState(() {
                                        errorMessage =
                                            'Unable to create account. Email may already exist.';
                                        isSubmitting = false;
                                      });
                                      return;
                                    }

                                    Navigator.of(dialogContext).pop(true);
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Account created. Continue to payment.',
                                        ),
                                      ),
                                    );
                                  },
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    isSignInMode
                                        ? Icons.login_rounded
                                        : Icons.person_add_alt_1_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              isSignInMode ? 'Sign In' : 'Create Account',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8C00),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    loginEmailController.dispose();
    loginPasswordController.dispose();
    signupEmailController.dispose();
    signupPasswordController.dispose();
    signupConfirmController.dispose();

    return result;
  }

  Future<void> _showPaymentModal(BuildContext context, _SubscriptionPlanOption plan) async {
    final messenger = ScaffoldMessenger.of(context);
    bool isProcessing = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: isProcessing ? null : () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Secure Checkout',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A173D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Selected Plan', style: TextStyle(color: Colors.black54, fontSize: 13)),
                                Text(
                                  '${plan.years} Year${plan.years > 1 ? 's' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            Text(
                              plan.amountLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      const Icon(Icons.lock_outline, size: 48, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text(
                        'You will be redirected to PayMongo to securely complete your payment using GCash, PayMaya, or Credit/Debit Card.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                            ],
                          ),
                        ),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  setState(() {
                                    errorMessage = null;
                                    isProcessing = true;
                                  });

                                  try {
                                    final authService = Provider.of<AuthService>(context, listen: false);
                                    final user = authService.currentUser;
                                    if (user == null || user['user_id'] == null) {
                                      setState(() {
                                        errorMessage = 'User not found. Please log in again.';
                                        isProcessing = false;
                                      });
                                      return;
                                    }
                                    
                                    final userId = user['user_id'];
                                    final response = await http.post(
                                      AppConfig.apiUri('subscription/paymongo-checkout/'),
                                      headers: {"Content-Type": "application/json"},
                                      body: json.encode({
                                        "user_id": userId,
                                        "subscription_years": plan.years
                                      }),
                                    );
                                    
                                    if (response.statusCode == 200) {
                                      final data = json.decode(response.body);
                                      if (data['success'] == true) {
                                        final checkoutUrl = data['checkout_url'];
                                        final uri = Uri.parse(checkoutUrl);
                                        
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          if (dialogContext.mounted) {
                                            Navigator.of(dialogContext).pop();
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text('Redirecting to secure PayMongo checkout...'),
                                                backgroundColor: Colors.green,
                                                duration: Duration(seconds: 4),
                                              ),
                                            );
                                          }
                                        } else {
                                          setState(() {
                                            errorMessage = 'Could not launch payment URL';
                                          });
                                        }
                                      } else {
                                        setState(() {
                                          errorMessage = 'Checkout failed: ${data['message']}';
                                        });
                                      }
                                    } else {
                                      setState(() {
                                        errorMessage = 'Server error: ${response.body}';
                                      });
                                    }
                                  } catch (e) {
                                    setState(() {
                                      errorMessage = 'Network error: ' + e.toString();
                                    });
                                  } finally {
                                    setState(() => isProcessing = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6F00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Proceed to Checkout',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _modalInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6E0EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6E0EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(
        color: Color(0xFF526171),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: Color(0xFF97A3B2), fontSize: 13),
    );
  }

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
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/engineer.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(child: _buildTextSection(context, isMobile)),
              ],
            )
          else
            Column(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/engineer.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextSection(context, isMobile),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTextSection(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Track every project with clarity",
          textAlign: TextAlign.center,
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
        Center(
          child: ElevatedButton(
            onPressed: () => _showPlanSelectionModal(context),
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
        ),
      ],
    );
  }
}

class _SubscriptionPlanOption {
  final int years;
  final String amountLabel;
  final String subtitle;
  final bool isPopular;

  const _SubscriptionPlanOption({
    required this.years,
    required this.amountLabel,
    required this.subtitle,
    this.isPopular = false,
  });
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
              children: [
                _footerColumns()[0], // Logo and Description
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _footerColumns()[2], // Quick Links
                    const SizedBox(width: 40),
                    _footerColumns()[4], // Contact Us
                  ],
                ),
              ],
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

class NotFoundPage extends StatelessWidget {
  final String lastKnownPath;

  const NotFoundPage({super.key, required this.lastKnownPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 72,
                color: Color(0xFFFF6B2C),
              ),
              const SizedBox(height: 16),
              const Text(
                'Page not found',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B1534),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'The page you entered does not exist or is no longer available.',
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(
                  lastKnownPath.trim().isEmpty ? '/' : lastKnownPath,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B2C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.home_rounded),
                label: const Text(
                  'Go back',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
