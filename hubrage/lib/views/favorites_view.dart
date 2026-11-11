import 'package:flutter/material.dart';
import '../models/admin_console_state.dart';
import '../models/dorm_catalog.dart';
import '../models/favorites_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dorm_card.dart';

/// หน้ารายการโปรด: หอพักที่ผู้เช่ากดหัวใจไว้
class FavoritesView extends StatelessWidget {
  final AdminConsoleState? consoleState;
  final FavoritesState favorites;
  final VoidCallback onGoSearch;

  const FavoritesView({
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
        final dorms = DormCatalog.visibleDorms(consoleState)
            .where((dorm) => favorites.isFavorite(dorm['title'].toString()))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: Row(
                children: [
                  const Text(
                    'รายการโปรด',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 13,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dorms.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: dorms.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      itemCount: dorms.length,
                      itemBuilder: (context, index) {
                        final dorm = dorms[index];
                        final title = dorm['title'].toString();
                        return DormCard(
                          dorm: dorm,
                          isFavorite: true,
                          onToggleFavorite: () => favorites.toggle(title),
                          onTap: () => openDormDetail(
                            context,
                            dorm: dorm,
                            favorites: favorites,
                            consoleState: consoleState,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 44,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ยังไม่มีหอพักที่บันทึกไว้',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'กดรูปหัวใจที่หอพักที่ถูกใจ\nแล้วจะมาอยู่ที่หน้านี้',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onGoSearch,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('ไปค้นหาหอพัก'),
            ),
          ],
        ),
      ),
    );
  }
}
