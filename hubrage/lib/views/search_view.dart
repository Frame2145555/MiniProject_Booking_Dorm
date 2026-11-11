import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../models/admin_console_state.dart';
import '../models/dorm_catalog.dart';
import '../models/favorites_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dorm_card.dart';

/// หน้าค้นหาหอพัก: ค้นหาตามชื่อ/มหาวิทยาลัย/ขนส่ง + กรองราคา + กรองสิ่งอำนวยความสะดวก
class SearchView extends StatefulWidget {
  final AdminConsoleState? consoleState;
  final FavoritesState favorites;

  /// แจ้งแถบบนของแอป (NavigationShell) ให้ยุบ/แสดง: false = ยุบขึ้น, true = แสดง
  final ValueChanged<bool>? onHeaderVisibleChanged;

  const SearchView({
    super.key,
    this.consoleState,
    required this.favorites,
    this.onHeaderVisibleChanged,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  RangeValues _selectedPriceRange = const RangeValues(3000, 12000);
  bool _isPriceFilterActive = false;
  final Set<String> _selectedAmenities = {};

  // แผงกรอง (แสดงในหน้าค้นหาเอง ไม่ใช้ modal เพื่อให้ header ด้านบนไม่ถูกบัง/ไม่มืด)
  _FilterPanel _panel = _FilterPanel.none;
  RangeValues _tempRange = const RangeValues(3000, 12000);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredDorms() {
    final query = _searchController.text.trim().toLowerCase();
    final dorms = DormCatalog.visibleDorms(widget.consoleState);

    return dorms.where((dorm) {
      final title = dorm['title'].toString().toLowerCase();
      final location = dorm['location'].toString().toLowerCase();

      // 1. ค้นหาตามชื่อหอ, มหาวิทยาลัย, ขนส่งสาธารณะ
      final matchesQuery =
          query.isEmpty || title.contains(query) || location.contains(query);

      // 2. ค้นหาตามช่วงราคา (ถ้าเปิดใช้งาน filter ราคา)
      final int dormMin = dorm['minPrice'];
      final int dormMax = dorm['maxPrice'];
      final matchesPrice =
          !_isPriceFilterActive ||
          (dormMin <= _selectedPriceRange.end &&
              dormMax >= _selectedPriceRange.start);

      // 3. ค้นหาตามสิ่งอำนวยความสะดวกที่เลือก
      final dormTags = List<String>.from(dorm['tags'] as List);
      final matchesAmenities =
          _selectedAmenities.isEmpty ||
          _selectedAmenities.every((amenity) => dormTags.contains(amenity));

      return matchesQuery && matchesPrice && matchesAmenities;
    }).toList();
  }

  void _setHeaderVisible(bool visible) =>
      widget.onHeaderVisibleChanged?.call(visible);

  /// เลื่อนรายการลง → ยุบ header ขึ้น / เลื่อนกลับขึ้น (หรืออยู่บนสุด) → แสดงกลับ
  bool _onListScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse) {
        _setHeaderVisible(false);
      } else if (n.direction == ScrollDirection.forward) {
        _setHeaderVisible(true);
      }
    } else if (n is ScrollUpdateNotification && n.metrics.pixels <= 0) {
      _setHeaderVisible(true);
    }
    return false;
  }

  void _showPriceRangeModal() {
    _setHeaderVisible(true);
    setState(() {
      _tempRange = _selectedPriceRange;
      _panel = _FilterPanel.price;
    });
  }

  void _closePanel() => setState(() => _panel = _FilterPanel.none);

  Widget _buildPricePanel() {
    final tempRange = _tempRange;
    return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'กรองตามช่วงราคา (บาท/เดือน)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _closePanel(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '฿${tempRange.start.round().toString()} - ฿${tempRange.end.round().toString()} บาท',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RangeSlider(
                    values: tempRange,
                    min: 3000,
                    max: 15000,
                    divisions: 24,
                    activeColor: AppColors.ink,
                    inactiveColor: AppColors.line,
                    labels: RangeLabels(
                      '฿${tempRange.start.round()}',
                      '฿${tempRange.end.round()}',
                    ),
                    onChanged: (RangeValues values) {
                      setState(() => _tempRange = values);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _isPriceFilterActive = false;
                              _selectedPriceRange = const RangeValues(
                                3000,
                                12000,
                              );
                            });
                            _closePanel();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('ล้างค่า'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedPriceRange = tempRange;
                              _isPriceFilterActive = true;
                            });
                            _closePanel();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('ตกลง'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
  }

  void _showAmenitiesModal() {
    _setHeaderVisible(true); // ระหว่างเลือก ให้ header ยังเห็นอยู่
    setState(() => _panel = _FilterPanel.amenities);
  }

  Widget _buildAmenitiesPanel(double height) {
    return Container(
              height: height,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, color: AppColors.ink),
                          const SizedBox(width: 8),
                          const Text(
                            'เลือกสิ่งอำนวยความสะดวก',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _closePanel(),
                      ),
                    ],
                  ),
                  const Text(
                    'สามารถเลือกหัวข้อที่ต้องการได้มากกว่า 1 รายการ',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: DormCatalog.amenities.map((item) {
                          final String label = item['label'];
                          final IconData icon = item['icon'];
                          final bool isSelected = _selectedAmenities.contains(
                            label,
                          );

                          return FilterChip(
                            showCheckmark: false,
                            avatar: Icon(
                              icon,
                              size: 16,
                              color: isSelected ? Colors.white : AppColors.ink,
                            ),
                            label: Text(label),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.ink,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.ink,
                            backgroundColor: AppColors.field,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.ink
                                    : AppColors.line,
                              ),
                            ),
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _selectedAmenities.add(label);
                                } else {
                                  _selectedAmenities.remove(label);
                                }
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedAmenities.clear();
                            });
                            setState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('ล้างทั้งหมด'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _closePanel();
                            _setHeaderVisible(false); // เลือกเสร็จ → ยุบ header ขึ้น
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text('ตกลง (${_selectedAmenities.length})'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
  }

  Widget _filterPill({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected ? AppShadows.dark : AppShadows.chip,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.ink,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Tooltip(
      message: 'สิ่งอำนวยความสะดวก',
      child: GestureDetector(
        onTap: _showAmenitiesModal,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.dark,
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
            if (_selectedAmenities.isNotEmpty)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: 1.5),
                  ),
                  child: Text(
                    '${_selectedAmenities.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable?>[
        widget.consoleState,
        widget.favorites,
        DormCatalog.live, // รายการหอจริงจาก server
      ]),
      builder: (context, _) {
        final filteredDorms = _getFilteredDorms();
        final content = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ค้นหาหอพัก',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      CircleIconButton(
                        tooltip: 'แผนที่หอพัก',
                        icon: Icons.map_outlined,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'แผนที่จะแสดงเมื่อเพิ่มพิกัดของหอพัก',
                                ),
                              ),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ช่องค้นหา (ชื่อหอ, มหาลัย, รถไฟฟ้า/ขนส่ง) + ปุ่มกรองสิ่งอำนวยความสะดวก
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppShadows.soft,
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'ค้นหาชื่อหอพัก, มหาวิทยาลัย, BTS/MRT...',
                              hintStyle: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.muted,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildFilterButton(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // แถบชิปกรอง (ช่วงราคา + สิ่งอำนวยความสะดวกที่เลือกไว้)
            SizedBox(
              height: 52,
              child: ListView(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                children: [
                  _filterPill(
                    icon: Icons.sell_outlined,
                    label: _isPriceFilterActive
                        ? 'ราคา: ฿${_selectedPriceRange.start.round()}-฿${_selectedPriceRange.end.round()}'
                        : 'ช่วงราคา',
                    selected: _isPriceFilterActive,
                    onTap: _showPriceRangeModal,
                  ),
                  const SizedBox(width: 10),
                  ..._selectedAmenities.map((amenity) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedAmenities.remove(amenity)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppShadows.soft,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                amenity,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: AppColors.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
              child: Row(
                children: [
                  const Text(
                    'ผลการค้นหา',
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
                      '${filteredDorms.length}',
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

            // แสดงรายการหอพัก
            Expanded(
              child: filteredDorms.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 56,
                            color: AppColors.muted,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'ไม่พบหอพักที่ตรงกับเงื่อนไขการค้นหา',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: _onListScroll,
                      child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      itemCount: filteredDorms.length,
                      itemBuilder: (context, index) {
                        final dorm = filteredDorms[index];
                        final title = dorm['title'].toString();
                        return DormCard(
                          dorm: dorm,
                          isFavorite: widget.favorites.isFavorite(title),
                          onToggleFavorite: () => widget.favorites.toggle(title),
                          onTap: () => openDormDetail(
                            context,
                            dorm: dorm,
                            favorites: widget.favorites,
                            consoleState: widget.consoleState,
                          ),
                        );
                      },
                    ),
                    ),
            ),
          ],
        );

        if (_panel == _FilterPanel.none) return content;

        // แผงกรองลอยอยู่ "ในพื้นที่ของหน้านี้" เท่านั้น → AppTopBar ของแอปยังเห็นครบและกดได้
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxH = constraints.maxHeight;
            return Stack(
              children: [
                content,
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closePanel,
                    child: Container(color: Colors.black.withOpacity(0.35)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Theme.of(context).canvasColor,
                    elevation: 8,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _panel == _FilterPanel.price
                        ? _buildPricePanel()
                        : _buildAmenitiesPanel(maxH * 0.85),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

enum _FilterPanel { none, price, amenities }
