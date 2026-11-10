import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_console_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dorm_gallery.dart';
import '../services/chat_service.dart';
import '../services/session.dart';
import 'auth_view.dart';
import 'chat_room_view.dart';

class DormDetailView extends StatefulWidget {
  final Map<String, dynamic> dorm;
  final AdminConsoleState? consoleState; // ใช้ดึงรีวิวที่แอดมินยังไม่ซ่อน
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteChanged;
  final Future<void> Function(DateTime visitAt)? onVisitRequest;

  const DormDetailView({
    super.key,
    this.dorm = const {},
    this.consoleState,
    this.isFavorite = false,
    this.onFavoriteChanged,
    this.onVisitRequest,
  });

  @override
  State<DormDetailView> createState() => _DormDetailViewState();
}

class _DormDetailViewState extends State<DormDetailView> {
  late bool _isFavorite = widget.isFavorite;
  int _heroPage = 0;

  /// รูปทั้งหมดของหอ: รูปหน้าปกก่อน ตามด้วยรูปเพิ่มเติมที่เจ้าของหออัปโหลด
  List<dynamic> get _galleryImages {
    final cover = widget.dorm['imageUrl']?.toString() ?? '';
    final extra = (widget.dorm['images'] as List?) ?? const [];
    return [if (cover.isNotEmpty) cover, ...extra];
  }

  String get _title => widget.dorm['title']?.toString() ?? 'หอรวย เธะ';
  String get _location =>
      widget.dorm['location']?.toString() ??
      'ซอยรามคำแหง 24 (แยก 2) • แขวงหัวหมาก เขตบางกะปิ กรุงเทพฯ';
  String get _price => widget.dorm['price']?.toString() ?? '5,000 - 8,500';
  String get _phone => widget.dorm['phone']?.toString() ?? '081-234-5678';
  String get _description =>
      widget.dorm['description']?.toString() ??
      'หอพักใกล้มหาวิทยาลัย เดินทางสะดวกและมีระบบรักษาความปลอดภัย';
  String? get _coordinates {
    final latitude = widget.dorm['latitude'];
    final longitude = widget.dorm['longitude'];
    if (latitude == null || longitude == null) return null;
    return '$latitude, $longitude';
  }

  static const _amenityIcons = <String, IconData>{
    'แอร์': Icons.ac_unit,
    'เครื่องปรับอากาศ': Icons.ac_unit,
    'Wi-Fi': Icons.wifi,
    'Wi-Fi ฟรี': Icons.wifi,
    'ที่จอดรถ': Icons.directions_car,
    'กล้องวงจรปิด': Icons.videocam,
    'ลิฟต์': Icons.elevator,
    'เครื่องทำน้ำอุ่น': Icons.hot_tub_outlined,
    'เลี้ยงสัตว์ได้': Icons.pets,
    'ฟิตเนส': Icons.fitness_center,
    'สระว่ายน้ำ': Icons.pool,
    'เครื่องซักผ้า': Icons.local_laundry_service,
    'รปภ. 24ชม.': Icons.security,
  };

  List<String> get _amenities =>
      List<String>.from(widget.dorm['tags'] ?? _amenityIcons.keys.take(8));

  // หน้าค้นหายังใช้ข้อมูลตัวอย่าง id แบบ 'dorm_1' จึงแปลงเป็นเลข id ใน MySQL ไปก่อน
  // (เปลี่ยนเป็น widget.dorm['id'] ตรงๆ ได้เมื่อรายการหอดึงจาก API แล้ว)
  int? get _dormDbId {
    final raw = widget.dorm['id']?.toString() ?? 'dorm_1';
    return int.tryParse(raw.replaceFirst('dorm_', ''));
  }

  bool _openingChat = false;

  /// ปุ่มแชท: เปิด (หรือสร้าง) ห้องแชทกับเจ้าของหอนี้บน server แล้วเข้าห้อง
  Future<void> _startChat() async {
    if (!Session.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณาเข้าสู่ระบบก่อนเริ่มแชท'),
          action: SnackBarAction(
            label: 'เข้าสู่ระบบ',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthView()),
            ),
          ),
        ),
      );
      return;
    }
    final dormId = _dormDbId;
    if (dormId == null || _openingChat) return;

    setState(() => _openingChat = true);
    final conversationId = await ChatService.instance.openConversation(dormId);
    if (!mounted) return;
    setState(() => _openingChat = false);

    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'เปิดห้องแชทไม่สำเร็จ (หอนี้อาจยังไม่มีในระบบ หรือคุณเป็นเจ้าของหอนี้)',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomView(
          conversationId: conversationId,
          title: 'เจ้าของหอ',
          subtitle: _title,
        ),
      ),
    );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    widget.onFavoriteChanged?.call(_isFavorite);
  }

  Future<void> _requestVisit() async {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 14, minute: 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('นัดเข้าดูห้องพัก'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                ),
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (value != null) setDialogState(() => selectedDate = value);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(selectedTime.format(context)),
                onPressed: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (value != null) setDialogState(() => selectedTime = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ยืนยันวันนัด'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final visitAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (widget.onVisitRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'เลือกวันนัดแล้ว — การส่งคำขอจะใช้งานได้เมื่อเชื่อมต่อระบบ',
          ),
        ),
      );
      return;
    }
    await widget.onVisitRequest!(visitAt);
  }

  Widget _heroSection(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          height: 320,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: AppShadows.soft,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF69707E), Color(0xFF2A2F3A)],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_galleryImages.isNotEmpty)
                  PageView.builder(
                    itemCount: _galleryImages.length,
                    onPageChanged: (i) => setState(() => _heroPage = i),
                    itemBuilder: (_, i) => DormGalleryImage(_galleryImages[i]),
                  )
                else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_rounded,
                        size: 52,
                        color: Colors.white.withOpacity(0.25),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'รูปภาพห้องพัก & มุมมอง 360°',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.65),
                      ],
                    ),
                  ),
                ),
                if (_galleryImages.length > 1)
                  Positioned(
                    bottom: 14,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _galleryImages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _heroPage ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _heroPage
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        CircleIconButton(
                          glass: true,
                          tooltip: 'ย้อนกลับ',
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      const Spacer(),
                      CircleIconButton(
                        glass: true,
                        tooltip: 'แชร์ประกาศ',
                        icon: Icons.share_outlined,
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: '$_title • $_location'),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('คัดลอกข้อมูลประกาศแล้ว'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'รูปตัวอย่าง',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 84,
                  bottom: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ค่าเช่า',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '฿$_price / เดือน',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: Tooltip(
                    message: _isFavorite
                        ? 'นำออกจากรายการโปรด'
                        : 'บันทึกรายการโปรด',
                    child: GestureDetector(
                      onTap: _toggleFavorite,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? AppColors.danger : Colors.white,
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
    );
  }

  Widget _bottomBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        color: AppColors.bg,
        child: Row(
          children: [
            Tooltip(
              message: 'เริ่มแชทกับเจ้าของหอ',
              child: SizedBox(
                width: 58,
                height: 58,
                child: OutlinedButton(
                  onPressed: _openingChat ? null : _startChat,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(58, 58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _openingChat
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.forum_rounded, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: _requestVisit,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('นัดเข้าดูห้องพัก'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: _bottomBar(context),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroSection(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: AppColors.star,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '4.7 / 5',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$_location${_coordinates == null ? '' : '\nพิกัด: $_coordinates'}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    'รายละเอียดหอพัก',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _description,
                    style: const TextStyle(
                      height: 1.6,
                      color: AppColors.muted,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    'สิ่งอำนวยความสะดวก',
                    icon: Icons.home_repair_service_outlined,
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.9,
                        ),
                    itemCount: _amenities.length,
                    itemBuilder: (context, index) {
                      final label = _amenities[index];
                      return Row(
                        children: [
                          Icon(
                            _amenityIcons[label] ?? Icons.check_circle_outline,
                            color: AppColors.muted,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.muted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    'รายละเอียดห้องพักและเงื่อนไข',
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 12),
                  const AppCard(
                    padding: EdgeInsets.all(18),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        '• ห้องเล็ก เตียง 5 ฟุต: 5,000 - 6,500 บาท/เดือน\n• ห้องใหญ่ เตียง 6 ฟุต: 7,000 - 8,500 บาท/เดือน\n• เงินประกัน 1 เดือน + ค่าเช่าล่วงหน้า 1 เดือน\n• ทำสัญญาและชำระเงินกับเจ้าของหอโดยตรง',
                        style: TextStyle(
                          height: 1.7,
                          color: AppColors.ink,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    'อัตราค่าสาธารณูปโภค',
                    icon: Icons.bolt_outlined,
                  ),
                  const SizedBox(height: 12),
                  _utilitiesTable(),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    'ติดต่อเจ้าของหอ',
                    icon: Icons.call_outlined,
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.accentSoft,
                        child: Icon(Icons.phone, color: AppColors.accent),
                      ),
                      title: Text(
                        _phone,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'โทรสอบถามห้องว่างและเงื่อนไข',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      trailing: IconButton(
                        tooltip: 'คัดลอกเบอร์โทร',
                        icon: const Icon(
                          Icons.copy_outlined,
                          color: AppColors.accent,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _phone));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('คัดลอกเบอร์โทรแล้ว'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    'รีวิวจากผู้เช่า',
                    icon: Icons.star_outline,
                  ),
                  const SizedBox(height: 12),
                  _reviewsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// รีวิวจากผู้เช่า — รีวิวที่แอดมินซ่อน/ลบแล้วจะไม่แสดงตรงนี้
  Widget _reviewsSection() {
    final state = widget.consoleState;
    final dormId = widget.dorm['id']?.toString();
    if (state == null || dormId == null) return _emptyReviews();
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final reviews = state.visibleReviewsFor(dormId);
        if (reviews.isEmpty) return _emptyReviews();
        return Column(
          children: reviews.map((r) {
            final rating = (r['rating'] as num).toInt();
            return AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r['author'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          r['date'].toString(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 17,
                          color: AppColors.star,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r['comment'].toString(),
                      style: const TextStyle(height: 1.45, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emptyReviews() => const AppCard(
    child: ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.field,
        child: Icon(Icons.person_outline, color: AppColors.muted),
      ),
      title: Text('ยังไม่มีรีวิว', style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        'รีวิวจะแสดงเมื่อมีผู้เช่าให้คะแนน',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    ),
  );

  Widget _utilitiesTable() => AppCard(
    child: Table(
      border: const TableBorder(
        horizontalInside: BorderSide(color: AppColors.line),
      ),
      children: const [
        TableRow(
          decoration: BoxDecoration(color: AppColors.field),
          children: [
            Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'รายการ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'อัตราค่าบริการ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.all(14),
              child: Text('ค่าไฟฟ้า', style: TextStyle(fontSize: 13)),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Text('7 บาท / หน่วย', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.all(14),
              child: Text('ค่าน้ำประปา', style: TextStyle(fontSize: 13)),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '18 บาท / หน่วย (ขั้นต่ำ 100 บาท)',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionHeader(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          boxShadow: AppShadows.soft,
        ),
        child: Icon(icon, size: 17, color: AppColors.ink),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
