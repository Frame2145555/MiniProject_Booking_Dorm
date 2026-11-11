import 'package:flutter/material.dart';
import 'models/user_role.dart';
import 'views/home_view.dart';
import 'views/search_view.dart';
import 'views/favorites_view.dart';
import 'views/chat_view.dart';
import 'views/auth_view.dart';
import 'views/owner_dashboard_view.dart';
import 'views/admin_dashboard_view.dart';
import 'views/my_bookings_view.dart';
import 'models/dorm_catalog.dart';
import 'services/admin_api_service.dart';
import 'models/admin_console_state.dart';
import 'models/favorites_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_top_bar.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  final AdminConsoleState _consoleState = AdminConsoleState();
  final FavoritesState _favorites = FavoritesState();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UserRole _currentRole = UserRole.tenant;
  int _currentIndex = 0;

  /// แถบบน (header) ยุบ/แสดงได้ — หน้าค้นหาของผู้เช่าสั่งยุบตอนเลื่อนรายการลง
  final ValueNotifier<bool> _headerVisible = ValueNotifier<bool>(true);

  /// สร้างหน้าของทุกบทบาทครั้งเดียว แล้วสลับด้วย IndexedStack
  /// เพื่อให้ข้อมูลในหน้า (เช่น หอที่เจ้าของเพิ่ม, ตัวกรองค้นหา) ไม่หายตอนสลับโหมดสิทธิ์
  late final Map<UserRole, List<Widget>> _pages = {
    UserRole.tenant: [
      HomeView(
        consoleState: _consoleState,
        favorites: _favorites,
        onGoSearch: () => _selectTab(1),
      ),
      SearchView(
        consoleState: _consoleState,
        favorites: _favorites,
        onHeaderVisibleChanged: (visible) => _headerVisible.value = visible,
      ),
      FavoritesView(
        consoleState: _consoleState,
        favorites: _favorites,
        onGoSearch: () => _selectTab(1),
      ),
      const ChatView(embedded: true),
    ],
    UserRole.seller: [
      OwnerDashboardView(consoleState: _consoleState),
      const ChatView(embedded: true, asSeller: true),
      const AuthView(embedded: true),
    ],
    UserRole.admin: [
      AdminDashboardView(consoleState: _consoleState),
      const AuthView(embedded: true),
    ],
  };

  @override
  void initState() {
    super.initState();
    DormCatalog.live.load(); // โหลดรายการหอจริงจาก server ตั้งแต่เปิดแอป
  }

  @override
  void dispose() {
    _consoleState.dispose();
    _favorites.dispose();
    _headerVisible.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    _headerVisible.value = true; // สลับแท็บแล้วแสดง header กลับเสมอ
    setState(() => _currentIndex = index);
  }

  void _onRoleChanged(UserRole newRole) {
    _headerVisible.value = true;
    // สลับโหมดแล้วดึงข้อมูลล่าสุด (เช่น เจ้าของเพิ่งเพิ่มหอ -> แอดมินเห็นคำขอใหม่)
    if (newRole == UserRole.tenant) DormCatalog.live.load();
    if (newRole == UserRole.admin && AdminApiService.isAdmin) {
      _consoleState.loadFromServer();
    }
    setState(() {
      _currentRole = newRole;
      _currentIndex = 0;
    });
  }

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthView()),
    );
  }

  String get _roleLabel {
    switch (_currentRole) {
      case UserRole.tenant:
        return 'ผู้เช่า';
      case UserRole.seller:
        return 'เจ้าของหอพัก';
      case UserRole.admin:
        return 'ศูนย์ควบคุมแอดมิน';
    }
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _getNavItemsForRole(_currentRole);
    final isTenant = _currentRole == UserRole.tenant;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: _buildDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // header ยุบขึ้น/แสดงแบบสมูท (ความสูง + ความจาง)
            ValueListenableBuilder<bool>(
              valueListenable: _headerVisible,
              builder: (context, visible, child) => TweenAnimationBuilder<double>(
                tween: Tween<double>(end: visible ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                child: child,
                builder: (context, t, child) => ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: t,
                    child: Opacity(opacity: t, child: child),
                  ),
                ),
              ),
              child: AppTopBar(
                subtitle: isTenant ? null : _roleLabel,
                onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                onNotifications: () => showNotificationsSheet(context),
                // ผู้เช่า: บัญชีอยู่ขวาบน ถัดจากกระดิ่งแจ้งเตือน
                onAccount: isTenant ? _openAccount : null,
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentRole.index,
                children: UserRole.values
                    .map(
                      (role) => IndexedStack(
                        index: role == _currentRole ? _currentIndex : 0,
                        children: _pages[role]!,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFloatingNav(navItems),
    );
  }

  // ───────────────────────── Drawer: โหมดสิทธิ์ ─────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppGradients.hero,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppShadows.dark,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dorm Master',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'แพลตฟอร์มค้นหาหอพัก',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.muted),
                  SizedBox(width: 6),
                  Text(
                    'โหมดสิทธิ์',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            _roleTile(
              role: UserRole.tenant,
              icon: Icons.person_search_rounded,
              title: 'ผู้เช่า (User)',
              subtitle: 'ค้นหา บันทึก และแชทกับเจ้าของหอ',
            ),
            _roleTile(
              role: UserRole.seller,
              icon: Icons.storefront_rounded,
              title: 'เจ้าของหอ (Seller)',
              subtitle: 'จัดการหอพัก ห้องพัก และประกาศ',
            ),
            _roleTile(
              role: UserRole.admin,
              icon: Icons.admin_panel_settings_rounded,
              title: 'แอดมิน (Admin)',
              subtitle: 'ตรวจเอกสารและดูแลบัญชีผู้ขาย',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                leading: const Icon(Icons.event_note_rounded),
                title: const Text(
                  'การจองและนัดดูห้องของฉัน',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context); // ปิดลิ้นชักเมนู
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBookingsView()),
                  );
                },
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Text(
                'โหมดสิทธิ์สำหรับทดสอบต้นแบบแอป',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleTile({
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _currentRole == role;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: selected ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.pop(context); // ปิดลิ้นชักเมนู
            _onRoleChanged(role);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.14)
                        : AppColors.field,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white70 : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Bottom navigation ─────────────────────────

  /// แถบเมนูล่างแบบลอย (มุมโค้ง สีเข้ม) ตามดีไซน์
  Widget _buildFloatingNav(List<BottomNavigationBarItem> items) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(26),
            boxShadow: AppShadows.dark,
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final selected = index == _currentIndex;
              final item = selected ? items[index].activeIcon : items[index].icon;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectTab(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: selected ? 22 : 0,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      IconTheme(
                        data: IconThemeData(
                          size: 24,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF8F95A1),
                        ),
                        child: item,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index].label ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF8F95A1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _getNavItemsForRole(UserRole role) {
    switch (role) {
      case UserRole.tenant:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'หน้าแรก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            activeIcon: Icon(Icons.search_rounded),
            label: 'ค้นหา',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border_rounded),
            activeIcon: Icon(Icons.favorite_rounded),
            label: 'รายการโปรด',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum_rounded),
            label: 'แชท',
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
