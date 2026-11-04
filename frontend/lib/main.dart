import 'package:flutter/material.dart';
import 'screens/admin_dashboard.dart';

void main() {
  runApp(const DormSpaceApp());
}

class DormSpaceApp extends StatelessWidget {
  const DormSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DormSpace Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          primary: const Color(0xFF4F46E5),
          surface: const Color(0xFFF8FAFC),
        ),
        fontFamily: 'Roboto',
      ),
      home: const AdminDashboardScreen(),
    );
  }
}
