import 'package:flutter/material.dart';

import '../shared/account_settings_view.dart';
import 'widgets/responsive_page_layout.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsivePageLayout(
      currentPage: 'Settings',
      title: 'Settings',
      child: AccountSettingsView(),
    );
  }
}
