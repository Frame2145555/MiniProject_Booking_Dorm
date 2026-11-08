import 'package:flutter/material.dart';
import '../models/admin_console_state.dart';
import 'dorm_detail_view.dart';

class HomeView extends StatefulWidget {
  final AdminConsoleState? consoleState;

  const HomeView({super.key, this.consoleState});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  RangeValues _selectedPriceRange = const RangeValues(3000, 12000);
  bool _isPriceFilterActive = false;
  final Set<String> _selectedAmenities = {};
  final Set<String> _favoriteDormTitles = {};
  bool _favoritesOnly = false;

  final List<Map<String, dynamic>> _allDorms = const [
    {
      'id': 'dorm_1',
      'title': 'หอรวย เธะ',
      'price': '5,000 - 8,500',
      'minPrice': 5000,
      'maxPrice': 8500,
      'rating': '4.7',
      'phone': '081-234-5678',
      'location': 'ซอยรามคำแหง 24 • ใกล้มหาวิทยาลัยรามคำแหง',
      'tags': ['แอร์', 'Wi-Fi', 'ที่จอดรถ'],
    },
    {
      'id': 'dorm_2',
      'title': 'หออิสลาม แกรนด์',
      'price': '6,500 - 9,000',
      'minPrice': 6500,
      'maxPrice': 9000,
      'rating': '4.0',
      'phone': '089-876-5432',
      'location': 'ซอยรามคำแหง 24 • ใกล้ Airport Link หัวหมาก',
      'tags': ['แอร์', 'กล้องวงจรปิด', 'ลิฟต์'],
    },
    {
      'id': 'dorm_3',
      'title': 'HU 24 อพาร์ตเมนต์',
      'price': '7,200 - 11,000',
      'minPrice': 7200,
      'maxPrice': 11000,
      'rating': '4.9',
      'phone': '082-333-4455',
      'location': 'รามคำแหง 24 แยก 2 • ใกล้เอแบค ABAC',
      'tags': ['ฟิตเนส', 'สระว่ายน้ำ', 'เลี้ยงสัตว์ได้', 'แอร์', 'ที่จอดรถ'],
    },
    {
      'id': 'dorm_4',
      'title': 'กรีนวิลล์ คอนโดเช่า',
      'price': '4,800 - 7,000',
      'minPrice': 4800,
      'maxPrice': 7000,
      'rating': '4.5',
      'phone': '086-555-6677',
      'location': 'ซอยหลังราม • ใกล้สนามราชมังคลาฯ และ MRT',
      'tags': ['เครื่องซักผ้า', 'รปภ. 24ชม.', 'แอร์', 'เลี้ยงสัตว์ได้'],
    },
  ];

  final List<Map<String, dynamic>> _allAmenities = const [
    {'label': 'แอร์', 'icon': Icons.ac_unit},
    {'label': 'เลี้ยงสัตว์ได้', 'icon': Icons.pets},
    {'label': 'ที่จอดรถ', 'icon': Icons.directions_car},
    {'label': 'Wi-Fi', 'icon': Icons.wifi},
    {'label': 'กล้องวงจรปิด', 'icon': Icons.videocam},
    {'label': 'ลิฟต์', 'icon': Icons.elevator},
    {'label': 'ฟิตเนส', 'icon': Icons.fitness_center},
    {'label': 'สระว่ายน้ำ', 'icon': Icons.pool},
    {'label': 'เครื่องซักผ้า', 'icon': Icons.local_laundry_service},
    {'label': 'รปภ. 24ชม.', 'icon': Icons.security},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredDorms() {
    final query = _searchController.text.trim().toLowerCase();
    final approvedOwnerDorms = (widget.consoleState?.approvedDorms ?? const [])
        .map(
          (request) => <String, dynamic>{
            ...request,
            'id': request['dormId'],
            'title': request['dormName'],
            'price': '${request['priceMin']} - ${request['priceMax']}',
            'minPrice': request['priceMin'],
            'maxPrice': request['priceMax'],
            'tags': request['amenities'] ?? <String>[],
          },
        );
    final dorms = [..._allDorms, ...approvedOwnerDorms];

    return dorms.where((dorm) {
      if (widget.consoleState?.isDormClosed(dorm['id'].toString()) ?? false) {
        return false;
      }
      if (_favoritesOnly && !_favoriteDormTitles.contains(dorm['title'])) {
        return false;
      }
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

  void _showPriceRangeModal() {
    RangeValues tempRange = _selectedPriceRange;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        onPressed: () => Navigator.pop(ctx),
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
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RangeSlider(
                    values: tempRange,
                    min: 3000,
                    max: 15000,
                    divisions: 24,
                    activeColor: Colors.deepOrange,
                    inactiveColor: Colors.orange.shade100,
                    labels: RangeLabels(
                      '฿${tempRange.start.round()}',
                      '฿${tempRange.end.round()}',
                    ),
                    onChanged: (RangeValues values) {
                      setModalState(() {
                        tempRange = values;
                      });
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
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
          },
        );
      },
    );
  }

  void _showAmenitiesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, color: Colors.deepOrange),
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
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'สามารถเลือกหัวข้อที่ต้องการได้มากกว่า 1 รายการ',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _allAmenities.map((item) {
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
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                            label: Text(label),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            selected: isSelected,
                            selectedColor: Colors.deepOrange,
                            backgroundColor: Colors.grey[100],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.deepOrange
                                    : Colors.grey[300]!,
                              ),
                            ),
                            onSelected: (bool selected) {
                              setModalState(() {
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
                            setModalState(() {
                              _selectedAmenities.clear();
                            });
                            setState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('ล้างทั้งหมด'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredDorms = _getFilteredDorms();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dorm Master',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            Text(
              'ค้นหาหอพักที่คุณถูกใจ',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'แผนที่หอพัก',
            icon: const Icon(Icons.map_outlined, color: Colors.deepOrange),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('แผนที่จะแสดงเมื่อเพิ่มพิกัดของหอพัก'),
              ),
            ),
          ),
          IconButton(
            tooltip: _favoritesOnly
                ? 'แสดงหอพักทั้งหมด'
                : 'ดูหอพักที่บันทึกไว้',
            icon: Icon(
              _favoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: Colors.deepOrange,
            ),
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // ช่องค้นหา (ชื่อหอ, มหาลัย, รถไฟฟ้า/ขนส่ง)
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อหอพัก, มหาวิทยาลัย, BTS/MRT...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.deepOrange,
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
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // แถบปุ่มหัวข้อใหญ่สำหรับกรองข้อมูล (ช่วงราคา + สิ่งอำนวยความสะดวก)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // ปุ่มหัวข้อใหญ่: ช่วงราคา
                      ActionChip(
                        avatar: Icon(
                          Icons.sell_outlined,
                          size: 16,
                          color: _isPriceFilterActive
                              ? Colors.white
                              : Colors.deepOrange,
                        ),
                        label: Text(
                          _isPriceFilterActive
                              ? 'ราคา: ฿${_selectedPriceRange.start.round()}-฿${_selectedPriceRange.end.round()}'
                              : 'ช่วงราคา',
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: _isPriceFilterActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _isPriceFilterActive
                              ? Colors.white
                              : Colors.black87,
                        ),
                        backgroundColor: _isPriceFilterActive
                            ? Colors.deepOrange
                            : Colors.orange.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _isPriceFilterActive
                                ? Colors.deepOrange
                                : Colors.orange.shade200,
                          ),
                        ),
                        onPressed: _showPriceRangeModal,
                      ),
                      const SizedBox(width: 8),

                      // ปุ่มหัวข้อใหญ่: สิ่งอำนวยความสะดวก (กดเปิด Modal เลือกตัวย่อย)
                      ActionChip(
                        avatar: Icon(
                          Icons.tune,
                          size: 16,
                          color: _selectedAmenities.isNotEmpty
                              ? Colors.white
                              : Colors.deepOrange,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedAmenities.isNotEmpty
                                  ? 'สิ่งอำนวยความสะดวก (${_selectedAmenities.length})'
                                  : 'สิ่งอำนวยความสะดวก',
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: _selectedAmenities.isNotEmpty
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedAmenities.isNotEmpty
                              ? Colors.white
                              : Colors.black87,
                        ),
                        backgroundColor: _selectedAmenities.isNotEmpty
                            ? Colors.deepOrange
                            : Colors.orange.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _selectedAmenities.isNotEmpty
                                ? Colors.deepOrange
                                : Colors.orange.shade200,
                          ),
                        ),
                        onPressed: _showAmenitiesModal,
                      ),
                      const SizedBox(width: 8),

                      // แสดง Tag สิ่งอำนวยความสะดวกที่เลือกไว้ทางด้านขวาเพิ่มเติม เพื่อความสะดวก
                      ..._selectedAmenities.map((amenity) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InputChip(
                            label: Text(
                              amenity,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.deepOrange,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            deleteIcon: const Icon(
                              Icons.cancel,
                              size: 14,
                              color: Colors.deepOrange,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Colors.deepOrange),
                            ),
                            onDeleted: () {
                              setState(() {
                                _selectedAmenities.remove(amenity);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // แสดงรายการหอพัก
          Expanded(
            child: filteredDorms.isEmpty
                ? const Center(
                    child: Text(
                      'ไม่พบหอพักที่ตรงกับเงื่อนไขการค้นหา',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredDorms.length,
                    itemBuilder: (context, index) {
                      final dorm = filteredDorms[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            widget.consoleState?.recordDormView(
                              dorm['id'].toString(),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DormDetailView(
                                  dorm: dorm,
                                  isFavorite: _favoriteDormTitles.contains(
                                    dorm['title'],
                                  ),
                                  onFavoriteChanged: (value) => setState(() {
                                    final title = dorm['title'].toString();
                                    if (value) {
                                      _favoriteDormTitles.add(title);
                                    } else {
                                      _favoriteDormTitles.remove(title);
                                    }
                                  }),
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    height: 150,
                                    width: double.infinity,
                                    color: Colors.orange.shade100,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.apartment_rounded,
                                          size: 56,
                                          color: Colors.deepOrange.shade300,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dorm['title'].toString(),
                                          style: TextStyle(
                                            color: Colors.deepOrange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${dorm['rating']} / 5',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white,
                                      child: IconButton(
                                        tooltip: 'บันทึกรายการโปรด',
                                        icon: Icon(
                                          _favoriteDormTitles.contains(
                                                dorm['title'],
                                              )
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() {
                                          final title = dorm['title']
                                              .toString();
                                          if (!_favoriteDormTitles.add(title))
                                            _favoriteDormTitles.remove(title);
                                        }),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dorm['title'].toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            dorm['location'].toString(),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '฿${dorm['price']}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.deepOrange,
                                                ),
                                              ),
                                              const TextSpan(
                                                text: ' บาท/เดือน',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: (dorm['tags'] as List<String>)
                                              .map(
                                                (tag) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 4,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.orange.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      tag,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors
                                                            .orange
                                                            .shade800,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
