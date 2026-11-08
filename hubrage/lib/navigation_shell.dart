import 'package:flutter/material.dart';
import 'models/user_role.dart';
import 'views/home_view.dart';
import 'views/dorm_detail_view.dart';
import 'views/chat_view.dart';
import 'views/auth_view.dart';
import 'views/owner_dashboard_view.dart';
import 'views/admin_dashboard_view.dart';
import 'models/admin_console_state.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  final AdminConsoleState _consoleState = AdminConsoleState();
  UserRole _currentRole = UserRole.tenant;
  int _currentIndex = 0;

  @override
  void dispose() {
    _consoleState.dispose();
    super.dispose();
  }

  void _onRoleChanged(UserRole newRole) {
    setState(() {
      _currentRole = newRole;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> currentPages = _getPagesForRole(_currentRole);
    final List<BottomNavigationBarItem> navItems = _getNavItemsForRole(
      _currentRole,
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.grey[900],
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.swap_horiz, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'โหมดสิทธิ์: ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text(
                    'ผู้เช่า (User)',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: _currentRole == UserRole.tenant,
                  onSelected: (_) => _onRoleChanged(UserRole.tenant),
                  selectedColor: Colors.deepOrange,
                  labelStyle: TextStyle(
                    color: _currentRole == UserRole.tenant
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text(
                    'เจ้าของหอ (Seller)',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: _currentRole == UserRole.seller,
                  onSelected: (_) => _onRoleChanged(UserRole.seller),
                  selectedColor: Colors.orange.shade800,
                  labelStyle: TextStyle(
                    color: _currentRole == UserRole.seller
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text(
                    'แอดมิน (Admin)',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: _currentRole == UserRole.admin,
                  onSelected: (_) => _onRoleChanged(UserRole.admin),
                  selectedColor: Colors.redAccent,
                  labelStyle: TextStyle(
                    color: _currentRole == UserRole.admin
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: currentPages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _getRoleColor(_currentRole),
        unselectedItemColor: Colors.grey[500],
        selectedFontSize: 12,
        unselectedFontSize: 11,
        elevation: 8,
        items: navItems,
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.tenant:
        return Colors.deepOrange;
      case UserRole.seller:
        return Colors.orange.shade800;
      case UserRole.admin:
        return Colors.redAccent;
    }
  }

  List<Widget> _getPagesForRole(UserRole role) {
    switch (role) {
      case UserRole.tenant:
        return [
          HomeView(consoleState: _consoleState),
          DormDetailView(),
          const ChatView(),
          const AuthView(),
        ];
      case UserRole.seller:
        return [
          OwnerDashboardView(consoleState: _consoleState),
          const ChatView(),
          const AuthView(),
        ];
      case UserRole.admin:
        return [
          AdminDashboardView(consoleState: _consoleState),
          const AuthView(),
        ];
    }
  }

  List<BottomNavigationBarItem> _getNavItemsForRole(UserRole role) {
    switch (role) {
      case UserRole.tenant:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: 'หน้าแรก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment_rounded),
            label: 'รายละเอียด',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_rounded),
            label: 'แชท',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'บัญชี',
          ),
        ];
      case UserRole.seller:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize_rounded),
            label: 'จัดการหอพัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_rounded),
            label: 'แชทผู้เช่า',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'บัญชี',
          ),
        ];
      case UserRole.admin:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_rounded),
            label: 'ศูนย์ควบคุม',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'บัญชี',
          ),
        ];
    }
  }
}
