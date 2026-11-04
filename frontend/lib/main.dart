import 'package:flutter/material.dart';

import 'views/dashboard_page.dart';

void main() {
  runApp(const DormSpaceApp());
}

class DormSpaceApp extends StatelessWidget {
  const DormSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DormSpace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}
