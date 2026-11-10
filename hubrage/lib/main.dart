import 'package:flutter/material.dart';
import 'navigation_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const DormMasterApp());
}

class DormMasterApp extends StatelessWidget {
  const DormMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dorm Master',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const NavigationShell(),
    );
  }
}
