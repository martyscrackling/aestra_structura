import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: true, // ✅ Ensure DEBUG banner shows
      home: const LicenseActivationPage(),
    );
  }
}

class LicenseActivationPage extends StatelessWidget {
  const LicenseActivationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 800;
          return Stack(
            children: [
              // Layout switch
              isMobile
                  ? _buildMobileLayout(context)
                  : _buildWideLayout(context),

              // Back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/sidebarlogin.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildContent(context: context, isMobile: false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double horizontalPadding = screenWidth < 360 ? 20 : 24;
    double verticalPadding = screenHeight < 700 ? 60 : 80;

    return Container(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _buildContent(
                context: context,
                isMobile: true,
                screenWidth: screenWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    bool isMobile = false,
    double screenWidth = 800,
  }) {
    double titleFont = isMobile ? (screenWidth < 360 ? 24 : 28) : 38;
    double priceFont = isMobile ? (screenWidth < 360 ? 52 : 60) : 64;
    double spacing = isMobile ? (screenWidth < 360 ? 16 : 20) : 20;
    double buttonFont = isMobile ? (screenWidth < 360 ? 13 : 15) : 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/structuralogo.png',
          height: isMobile ? 100 : 80,
        ),
        const SizedBox(height: 6),
        Text(
          'STRUCTURA',
          style: TextStyle(
            fontSize: titleFont,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0A173D),
            letterSpacing: 3,
            shadows: const [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 2,
                color: Colors.black26,
              ),
            ],
          ),
        ),

        SizedBox(height: spacing),
        Text(
          "₱5000",
          style: TextStyle(
            fontSize: priceFont,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFF6B2C),
          ),
        ),
        Text(
          "1 year plan",
          style: TextStyle(
            fontSize: screenWidth < 360 ? 12 : 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 30),

        Column(
          children: [
            FeatureItem(
              text: "Worker Management & Smart Attendance",
              isMobile: isMobile,
              screenWidth: screenWidth,
            ),
            FeatureItem(
              text: "Project Progress Tracking",
              isMobile: isMobile,
              screenWidth: screenWidth,
            ),
            FeatureItem(
              text: "Client Portal",
              isMobile: isMobile,
              screenWidth: screenWidth,
            ),
            FeatureItem(
              text: "Communication & Collaboration Tools",
              isMobile: isMobile,
              screenWidth: screenWidth,
            ),
            FeatureItem(
              text: "Reporting & Analytics",
              isMobile: isMobile,
              screenWidth: screenWidth,
            ),
            FeatureItem(
              text: "Accountability & Monitoring",
              isMobile: isMobile,
              screenWidth: screenWidth,
            ),
            FeatureItem(
              text: "System Security & Access Control",
              isMobile: isMobile,
              screenWidth: screenWidth,
            ),
          ],
        ),
        SizedBox(height: spacing * 1.5),
        SizedBox(
          width: double.infinity,
          height: screenWidth < 360 ? 48 : 50,
          child: ElevatedButton(
            onPressed: () {
              context.go('/dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B2C),
              padding: EdgeInsets.symmetric(
                vertical: screenWidth < 360 ? 12 : 14,
                horizontal: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Start your 14 days trial",
                style: TextStyle(
                  fontSize: buttonFont,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FeatureItem extends StatelessWidget {
  final String text;
  final bool isMobile;
  final double screenWidth;

  const FeatureItem({
    required this.text,
    this.isMobile = false,
    this.screenWidth = 800,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    double verticalPadding = isMobile ? (screenWidth < 360 ? 5 : 6) : 6;
    double iconSize = isMobile ? (screenWidth < 360 ? 14 : 16) : 16;
    double fontSize = isMobile ? (screenWidth < 360 ? 13 : 14) : 15;
    double iconPadding = isMobile ? (screenWidth < 360 ? 4 : 5) : 5;
    double horizontalSpacing = isMobile ? (screenWidth < 360 ? 10 : 12) : 12;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFF6B2C),
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(iconPadding),
            child: Icon(Icons.check, size: iconSize, color: Colors.white),
          ),
          SizedBox(width: horizontalSpacing),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
