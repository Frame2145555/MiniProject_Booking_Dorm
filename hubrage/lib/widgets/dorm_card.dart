import 'package:flutter/material.dart';

import '../models/admin_console_state.dart';
import '../models/favorites_state.dart';
import '../theme/app_theme.dart';
import '../views/dorm_detail_view.dart';

/// เปิดหน้ารายละเอียดหอพัก (บันทึกยอดเข้าชม + ซิงก์หัวใจกับ FavoritesState)
void openDormDetail(
  BuildContext context, {
  required Map<String, dynamic> dorm,
  required FavoritesState favorites,
  AdminConsoleState? consoleState,
}) {
  final title = dorm['title'].toString();
  consoleState?.recordDormView(dorm['id'].toString());
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DormDetailView(
        dorm: dorm,
        consoleState: consoleState,
        isFavorite: favorites.isFavorite(title),
        onFavoriteChanged: (value) => favorites.set(title, value),
      ),
    ),
  );
}

/// การ์ดหอพักที่ผู้เช่าเห็น (ใช้ร่วมกันในหน้าแรก / ค้นหา / รายการโปรด)
class DormCard extends StatelessWidget {
  final Map<String, dynamic> dorm;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const DormCard({
    super.key,
    required this.dorm,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final title = dorm['title'].toString();
    final tags = List<String>.from((dorm['tags'] as List?) ?? const []);
    final rating = dorm['rating']?.toString();
    final imageUrl = dorm['imageUrl']?.toString() ?? '';
    final gradient = AppGradients.coverFor(title);

    final Widget placeholder = DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Center(
        child: Icon(
          Icons.apartment_rounded,
          size: 84,
          color: Colors.white.withOpacity(0.14),
        ),
      ),
    );
    final Widget cover = imageUrl.isNotEmpty
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          )
        : placeholder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 236,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: AppShadows.soft,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover,
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.35, 1],
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.65),
                          ],
                        ),
                      ),
                    ),
                    // ป้ายราคา
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '฿${dorm['price']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const TextSpan(
                                text: ' /เดือน',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // คะแนน (หอใหม่ที่ยังไม่มีคะแนนจะแสดงเป็น "ใหม่")
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              rating == null
                                  ? Icons.fiber_new_rounded
                                  : Icons.star_rounded,
                              color: AppColors.star,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating == null ? 'ใหม่' : rating,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 76,
                      bottom: 18,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  dorm['location']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Tooltip(
                        message: 'บันทึกรายการโปรด',
                        child: GestureDetector(
                          onTap: onToggleFavorite,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: isFavorite
                                  ? Colors.white
                                  : Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite
                                  ? AppColors.danger
                                  : Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
