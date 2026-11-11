import 'package:flutter/material.dart';
import '../models/admin_console_state.dart';
import '../models/dorm_catalog.dart';
import '../models/favorites_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dorm_card.dart';

/// หน้าแรกของผู้เช่า: คำทักทาย + ช่องค้นหา (ยุบขึ้นแบบสมูทเมื่อเลื่อนลง) + รายการหอพัก
class HomeView extends StatelessWidget {
  final AdminConsoleState? consoleState;
  final FavoritesState favorites;
  final VoidCallback onGoSearch;

  const HomeView({
    super.key,
    this.consoleState,
    required this.favorites,
    required this.onGoSearch,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable?>[
        consoleState,
        favorites,
        DormCatalog.live, // รายการหอจริงจาก server
      ]),
      builder: (context, _) {
        final dorms = DormCatalog.visibleDorms(consoleState);
        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ส่วนหัวที่ยุบได้: คำทักทายจางหาย/เลื่อนขึ้น เหลือช่องค้นหาติดอยู่ด้านบน
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeHeaderDelegate(onSearchTap: onGoSearch),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                child: Row(
                  children: [
                    const Text(
                      'รายการหอพัก',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${dorms.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ต่อ server ไม่ได้ -> แสดงหอตัวอย่าง พร้อมบอกให้รู้ว่าไม่ใช่ข้อมูลจริง
            if (dorms.isNotEmpty &&
                !DormCatalog.live.hasServerData &&
                DormCatalog.live.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: AppCard(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off_outlined),
                      title: const Text(
                        'แสดงหอตัวอย่าง (ต่อ server ไม่ได้)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        DormCatalog.live.error!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        tooltip: 'ลองใหม่',
                        icon: const Icon(Icons.refresh),
                        onPressed: DormCatalog.live.load,
                      ),
                    ),
                  ),
                ),
              ),
            if (dorms.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: _emptyState()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final dorm = dorms[index];
                    final title = dorm['title'].toString();
                    return DormCard(
                      dorm: dorm,
                      isFavorite: favorites.isFavorite(title),
                      onToggleFavorite: () => favorites.toggle(title),
                      onTap: () => openDormDetail(
                        context,
                        dorm: dorm,
                        favorites: favorites,
                        consoleState: consoleState,
                      ),
                    );
                  }, childCount: dorms.length),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// ไม่มีหอให้แสดง: กำลังโหลด / โหลดไม่สำเร็จ (กดลองใหม่ได้) / ไม่มีหอจริงๆ
Widget _emptyState() {
  final store = DormCatalog.live;
  if (store.isLoading) return const CircularProgressIndicator();
  if (store.error != null) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            store.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: store.load,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
  return const Text(
    'ยังไม่มีหอพักในขณะนี้',
    style: TextStyle(color: AppColors.muted, fontSize: 16),
  );
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onSearchTap;

  _HomeHeaderDelegate({required this.onSearchTap});

  static const double _heroHeight = 96; // ส่วนคำทักทายที่ยุบหายไป
  static const double _searchHeight = 76; // ช่องค้นหาที่ค้างอยู่ด้านบน

  @override
  double get maxExtent => _heroHeight + _searchHeight;

  @override
  double get minExtent => _searchHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    // คำทักทายจางเร็วกว่าการยุบ เพื่อให้ดูนุ่มนวลไม่ซ้อนกับช่องค้นหา
    final heroOpacity = (1 - Curves.easeIn.transform((t * 1.35).clamp(0.0, 1.0)));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        boxShadow: t > 0.98
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            height: _heroHeight,
            child: Opacity(
              opacity: heroOpacity,
              child: Transform.translate(
                offset: Offset(0, -shrinkOffset * 0.35),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ค้นหาหอพัก\nที่คุณถูกใจ',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 0,
            height: _searchHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onSearchTap,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppShadows.chip,
                    ),
                    padding: const EdgeInsets.only(left: 16, right: 7),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.muted),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'ค้นหาชื่อหอพัก, มหาวิทยาลัย, BTS/MRT...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) =>
      oldDelegate.onSearchTap != onSearchTap;
}
