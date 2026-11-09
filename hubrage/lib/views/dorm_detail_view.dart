import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/chat_service.dart';
import '../services/session.dart';
import 'chat_room_view.dart';

class DormDetailView extends StatefulWidget {
  final Map<String, dynamic> dorm;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteChanged;
  final Future<void> Function(DateTime visitAt)? onVisitRequest;

  const DormDetailView({
    super.key,
    this.dorm = const {},
    this.isFavorite = false,
    this.onFavoriteChanged,
    this.onVisitRequest,
  });

  @override
  State<DormDetailView> createState() => _DormDetailViewState();
}

class _DormDetailViewState extends State<DormDetailView> {
  late bool _isFavorite = widget.isFavorite;

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

  // หน้า Home ยังใช้ข้อมูลตัวอย่าง id แบบ 'dorm_1' จึงแปลงเป็นเลข id ใน MySQL ไปก่อน
  // (เปลี่ยนเป็น widget.dorm['id'] ตรงๆ ได้เมื่อหน้า Home ดึงหอจาก API แล้ว)
  int? get _dormDbId {
    final raw = widget.dorm['id']?.toString() ?? 'dorm_1';
    return int.tryParse(raw.replaceFirst('dorm_', ''));
  }

  bool _openingChat = false;

  Future<void> _startChat() async {
    if (!Session.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนเริ่มแชท')),
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
          content: Text('เปิดห้องแชทไม่สำเร็จ (หอนี้อาจยังไม่มีในระบบ หรือคุณเป็นเจ้าของหอนี้)'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomView(
          conversationId: conversationId,
          title: _title,
          subtitle: 'แชทกับเจ้าของหอ',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดหอพัก'),
        actions: [
          IconButton(
            tooltip: 'แชร์ประกาศ',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: '$_title • $_location'),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('คัดลอกข้อมูลประกาศแล้ว')),
                );
              }
            },
          ),
          IconButton(
            tooltip: _isFavorite ? 'นำออกจากรายการโปรด' : 'บันทึกรายการโปรด',
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.redAccent : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              color: Colors.blueGrey[100],
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_rounded,
                        size: 48,
                        color: Colors.blueGrey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'รูปภาพห้องพัก & มุมมอง 360°',
                        style: TextStyle(
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'รูปตัวอย่าง',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '4.7 / 5',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$_location${_coordinates == null ? '' : '\nพิกัด: $_coordinates'}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '฿$_price / เดือน',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 32),
                  const _SectionHeader(
                    'รายละเอียดหอพัก',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 8),
                  Text(_description, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 20),
                  const _SectionHeader(
                    'สิ่งอำนวยความสะดวก',
                    icon: Icons.home_repair_service_outlined,
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.95,
                        ),
                    itemCount: _amenities.length,
                    itemBuilder: (context, index) {
                      final label = _amenities[index];
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _amenityIcons[label] ??
                                  Icons.check_circle_outline,
                              color: Colors.deepOrange,
                              size: 25,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    'รายละเอียดห้องพักและเงื่อนไข',
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• ห้องเล็ก เตียง 5 ฟุต: 5,000 - 6,500 บาท/เดือน\n• ห้องใหญ่ เตียง 6 ฟุต: 7,000 - 8,500 บาท/เดือน\n• เงินประกัน 1 เดือน + ค่าเช่าล่วงหน้า 1 เดือน\n• ทำสัญญาและชำระเงินกับเจ้าของหอโดยตรง',
                    style: TextStyle(height: 1.6, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  const _SectionHeader(
                    'อัตราค่าสาธารณูปโภค',
                    icon: Icons.bolt_outlined,
                  ),
                  const SizedBox(height: 8),
                  _utilitiesTable(),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    'ติดต่อเจ้าของหอ',
                    icon: Icons.call_outlined,
                  ),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF3E0),
                        child: Icon(Icons.phone, color: Colors.deepOrange),
                      ),
                      title: Text(_phone),
                      subtitle: const Text('โทรสอบถามห้องว่างและเงื่อนไข'),
                      trailing: IconButton(
                        tooltip: 'คัดลอกเบอร์โทร',
                        icon: const Icon(Icons.copy_outlined),
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
                  const SizedBox(height: 20),
                  const _SectionHeader(
                    'รีวิวจากผู้เช่า',
                    icon: Icons.star_outline,
                  ),
                  const Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text('รีวิวตัวอย่าง'),
                      subtitle: Text('รีวิวจริงจะแสดงเมื่อมีผู้เช่าให้คะแนน'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openingChat ? null : _startChat,
                      icon: const Icon(Icons.forum_rounded),
                      label: const Text('เริ่มแชทกับเจ้าของหอ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _requestVisit,
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('นัดเข้าดูห้องพัก'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange,
                        side: const BorderSide(color: Colors.deepOrange),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _utilitiesTable() => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Table(
      children: const [
        TableRow(
          decoration: BoxDecoration(color: Color(0xFFF1F3F5)),
          children: [
            Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'รายการ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'อัตราค่าบริการ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(padding: EdgeInsets.all(10), child: Text('ค่าไฟฟ้า')),
            Padding(padding: EdgeInsets.all(10), child: Text('7 บาท / หน่วย')),
          ],
        ),
        TableRow(
          children: [
            Padding(padding: EdgeInsets.all(10), child: Text('ค่าน้ำประปา')),
            Padding(
              padding: EdgeInsets.all(10),
              child: Text('18 บาท / หน่วย (ขั้นต่ำ 100 บาท)'),
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
      Icon(icon, color: Colors.deepOrange),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ],
  );
}
