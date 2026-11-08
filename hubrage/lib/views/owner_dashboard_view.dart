import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/admin_console_state.dart';
import '../models/dorm_model.dart';

class OwnerDashboardView extends StatefulWidget {
  final AdminConsoleState consoleState;

  const OwnerDashboardView({super.key, required this.consoleState});

  @override
  State<OwnerDashboardView> createState() => _OwnerDashboardViewState();
}

class _OwnerDashboardViewState extends State<OwnerDashboardView> {
  bool _isSubscribed = true;
  DateTime _subExpiryDate = DateTime.now().add(const Duration(days: 25));
  static const _currentSellerId = 'seller_001';

  bool get _sellerSuspended =>
      widget.consoleState.isSellerSuspended(_currentSellerId);

  final List<Map<String, dynamic>> _myDorms = [
    {
      'id': 'dorm_1',
      'sellerId': 'seller_001',
      'title': 'หอรวย เธะ (รามคำแหง 24)',
      'location': 'ซอยรามคำแหง 24 แยก 2',
      'phone': '081-234-5678',
      'description': 'หอพักใกล้มหาวิทยาลัย มีระบบรักษาความปลอดภัย',
      'priceMin': 5000,
      'priceMax': 8500,
      'amenities': ['แอร์', 'Wi-Fi', 'ที่จอดรถ'],
      'totalRooms': 24,
      'imageUrl': '', // ว่างไว้ได้ (เป็นทางเลือก)
      'roomsList': [
        RoomDetailModel(
          roomNumber: '101',
          roomType: 'เตียง 5 ฟุต',
          price: 5500,
          status: 'ว่าง',
        ),
        RoomDetailModel(
          roomNumber: '102',
          roomType: 'เตียง 5 ฟุต',
          price: 5500,
          status: 'มีผู้เช่า',
        ),
        RoomDetailModel(
          roomNumber: '103',
          roomType: 'เตียง 6 ฟุต (VIP)',
          price: 7500,
          status: 'ว่าง',
        ),
        RoomDetailModel(
          roomNumber: '104',
          roomType: 'เตียง 6 ฟุต (VIP)',
          price: 7500,
          status: 'ปรับปรุง',
        ),
      ],
    },
    {
      'id': 'dorm_2',
      'sellerId': 'seller_002',
      'title': 'หออิสลาม แกรนด์',
      'location': 'ซอยรามคำแหง 24',
      'phone': '089-876-5432',
      'description': 'หอพักทำเลสะดวก มีระบบรักษาความปลอดภัย',
      'priceMin': 6500,
      'priceMax': 9000,
      'amenities': ['แอร์', 'กล้องวงจรปิด', 'ลิฟต์'],
      'totalRooms': 18,
      'imageUrl': '',
      'roomsList': [
        RoomDetailModel(
          roomNumber: '201',
          roomType: 'เตียง 6 ฟุต',
          price: 6500,
          status: 'มีผู้เช่า',
        ),
        RoomDetailModel(
          roomNumber: '202',
          roomType: 'เตียง 6 ฟุต',
          price: 6500,
          status: 'ว่าง',
        ),
      ],
    },
  ];

  // คำนวณจำนวนห้องว่างของแต่ละหอพัก
  int _getAvailableRoomsCount(Map<String, dynamic> dorm) {
    final rooms = dorm['roomsList'] as List<RoomDetailModel>;
    return rooms.where((r) => r.status == 'ว่าง').length;
  }

  // คำนวณจำนวนห้องที่มีผู้เช่า
  int _getOccupiedRoomsCount(Map<String, dynamic> dorm) {
    final rooms = dorm['roomsList'] as List<RoomDetailModel>;
    return rooms.where((r) => r.status == 'มีผู้เช่า').length;
  }

  // แสดง Dialog ชำระค่าสมาชิก
  void _showSubscriptionPaymentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('ชำระค่าบริการรายเดือน'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'แพ็กเกจเจ้าของหอพัก (Seller Plan)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              '• สิทธิ์ลงประกาศหอพักไม่จำกัดห้อง\n'
              '• ระบบจัดการข้อมูลหอพักและห้องพักในแอป\n'
              '• อัตราค่าบริการ: ฿500 / เดือน',
              style: TextStyle(height: 1.5),
            ),
            const Divider(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 100),
                    Text(
                      'สแกน QR PromptPay ฿500.00',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isSubscribed = true;
                _subExpiryDate = DateTime.now().add(const Duration(days: 30));
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ต่ออายุแพ็กเกจรายเดือน 500 บาท สำเร็จ!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยันแจ้งชำระเงิน'),
          ),
        ],
      ),
    );
  }

  void _showEditDormDialog(Map<String, dynamic> dorm) {
    final titleController = TextEditingController(
      text: dorm['title']?.toString() ?? '',
    );
    final addressController = TextEditingController(
      text: dorm['location']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: dorm['phone']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: dorm['description']?.toString() ?? '',
    );
    final minPriceController = TextEditingController(
      text: dorm['priceMin']?.toString() ?? '',
    );
    final maxPriceController = TextEditingController(
      text: dorm['priceMax']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: dorm['imageUrl']?.toString() ?? '',
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('แก้ไขประกาศหอพัก'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'ชื่อหอพัก'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'ที่อยู่ / ทำเล'),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'เบอร์ติดต่อผู้ดูแลหอ',
                ),
              ),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'รายละเอียดหอพัก'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ค่าเช่าต่ำสุด',
                        prefixText: '฿',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ค่าเช่าสูงสุด',
                        prefixText: '฿',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: imageController,
                decoration: const InputDecoration(labelText: 'URL รูปหน้าปก'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty ||
                  addressController.text.trim().isEmpty ||
                  phoneController.text.trim().isEmpty ||
                  descriptionController.text.trim().isEmpty ||
                  int.tryParse(minPriceController.text) == null ||
                  int.tryParse(maxPriceController.text) == null ||
                  int.parse(maxPriceController.text) <
                      int.parse(minPriceController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณากรอกรายละเอียดและช่วงราคาให้ครบ'),
                  ),
                );
                return;
              }
              setState(() {
                dorm['title'] = titleController.text.trim();
                dorm['location'] = addressController.text.trim();
                dorm['phone'] = phoneController.text.trim();
                dorm['description'] = descriptionController.text.trim();
                dorm['priceMin'] = int.tryParse(minPriceController.text);
                dorm['priceMax'] = int.tryParse(maxPriceController.text);
                dorm['imageUrl'] = imageController.text.trim();
              });
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('อัปเดตข้อมูลตัวอย่างแล้ว')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    ).then((_) {
      titleController.dispose();
      addressController.dispose();
      phoneController.dispose();
      descriptionController.dispose();
      minPriceController.dispose();
      maxPriceController.dispose();
      imageController.dispose();
    });
  }

  Future<void> _pickDormDocument({
    required String type,
    required List<Map<String, String>> documents,
    required void Function(void Function()) setDialogState,
  }) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (files.isEmpty) return;
      final file = files.single;
      setDialogState(() {
        documents.removeWhere((document) => document['type'] == type);
        documents.add({'type': type, 'name': file.name});
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปิดตัวเลือกเอกสารไม่สำเร็จ')),
        );
      }
    }
  }

  void _showAddDormDialog() {
    if (_sellerSuspended) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บัญชีถูกระงับ กรุณาติดต่อแอดมิน')),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final latitudeCtrl = TextEditingController();
    final longitudeCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final minPriceCtrl = TextEditingController();
    final maxPriceCtrl = TextEditingController();
    final imageUrlCtrl = TextEditingController();
    final amenities = <String>[];
    final documents = <Map<String, String>>[];
    const availableAmenities = [
      'แอร์',
      'Wi-Fi',
      'ที่จอดรถ',
      'กล้องวงจรปิด',
      'ลิฟต์',
      'เครื่องทำน้ำอุ่น',
      'เลี้ยงสัตว์ได้',
      'ฟิตเนส',
      'สระว่ายน้ำ',
      'เครื่องซักผ้า',
      'รปภ. 24ชม.',
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_business_rounded, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text('ลงประกาศหอพัก'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'กรอกรายละเอียดที่ผู้เช่าจะเห็นในหน้าประกาศ',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อหอพัก *',
                      prefixIcon: Icon(Icons.apartment),
                    ),
                  ),
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ที่อยู่เต็ม / ทำเล *',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'พิกัดหอพัก (ถ้ามี): เปิด Google Maps ที่หอ กดค้างบนจุดหอ แล้วคัดลอกตัวเลขคู่ เช่น 13.7563, 100.5018',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latitudeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'ละติจูด',
                            hintText: '13.7563',
                            prefixIcon: Icon(Icons.explore_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: longitudeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'ลองจิจูด',
                            hintText: '100.5018',
                            prefixIcon: Icon(Icons.explore_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'เบอร์ติดต่อผู้ดูแลหอ *',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                  TextField(
                    controller: descriptionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'รายละเอียดหอพัก *',
                      hintText: 'จุดเด่น การเดินทาง กฎการพักอาศัย',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ค่าเช่าต่ำสุด/เดือน *',
                            prefixText: '฿',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ค่าเช่าสูงสุด/เดือน *',
                            prefixText: '฿',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'สิ่งอำนวยความสะดวก',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: availableAmenities
                        .map(
                          (amenity) => FilterChip(
                            label: Text(amenity),
                            selected: amenities.contains(amenity),
                            selectedColor: Colors.orange.shade100,
                            onSelected: (selected) => setDialogState(() {
                              if (selected) {
                                amenities.add(amenity);
                              } else {
                                amenities.remove(amenity);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  TextField(
                    controller: imageUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ลิงก์รูปหน้าปก (ถ้ามี)',
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'เอกสารประกอบการลงหอ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'จำเป็น: หลักฐานกรรมสิทธิ์หรือสิทธิ์ให้เช่า เช่น โฉนด สัญญาเช่า หรือหนังสือมอบอำนาจ',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _pickDormDocument(
                      type: 'proof_of_right',
                      documents: documents,
                      setDialogState: setDialogState,
                    ),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(
                      documents.any(
                            (document) => document['type'] == 'proof_of_right',
                          )
                          ? 'เปลี่ยนเอกสารสิทธิ์'
                          : 'แนบเอกสารสิทธิ์ให้เช่า *',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDormDocument(
                      type: 'business_registration',
                      documents: documents,
                      setDialogState: setDialogState,
                    ),
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      documents.any(
                            (document) =>
                                document['type'] == 'business_registration',
                          )
                          ? 'เปลี่ยนใบอนุญาต/ทะเบียนธุรกิจ'
                          : 'แนบใบอนุญาตหรือทะเบียนธุรกิจ (ถ้ามี)',
                    ),
                  ),
                  ...documents.map(
                    (document) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.description_outlined,
                        color: Colors.green,
                      ),
                      title: Text(document['name'] ?? ''),
                      subtitle: Text(
                        document['type'] == 'proof_of_right'
                            ? 'หลักฐานสิทธิ์ให้เช่า • จำเป็น'
                            : 'ใบอนุญาต/ทะเบียนธุรกิจ',
                      ),
                      trailing: IconButton(
                        tooltip: 'นำเอกสารออก',
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () =>
                            setDialogState(() => documents.remove(document)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                final minPrice = int.tryParse(minPriceCtrl.text);
                final maxPrice = int.tryParse(maxPriceCtrl.text);
                final latitudeText = latitudeCtrl.text.trim();
                final longitudeText = longitudeCtrl.text.trim();
                final latitude = double.tryParse(latitudeText);
                final longitude = double.tryParse(longitudeText);
                final hasProof = documents.any(
                  (document) => document['type'] == 'proof_of_right',
                );
                if (titleCtrl.text.trim().isEmpty ||
                    addressCtrl.text.trim().isEmpty ||
                    phoneCtrl.text.trim().isEmpty ||
                    descriptionCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'กรุณากรอกชื่อ ที่อยู่ เบอร์โทร และรายละเอียดหอให้ครบ',
                      ),
                    ),
                  );
                  return;
                }
                if (minPrice == null ||
                    maxPrice == null ||
                    minPrice <= 0 ||
                    maxPrice < minPrice) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณาระบุช่วงค่าเช่าให้ถูกต้อง'),
                    ),
                  );
                  return;
                }
                if ((latitudeText.isEmpty != longitudeText.isEmpty) ||
                    (latitudeText.isNotEmpty &&
                        (latitude == null ||
                            longitude == null ||
                            latitude < -90 ||
                            latitude > 90 ||
                            longitude < -180 ||
                            longitude > 180))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'กรุณากรอกพิกัดให้ครบ และใช้ละติจูด -90 ถึง 90 / ลองจิจูด -180 ถึง 180',
                      ),
                    ),
                  );
                  return;
                }
                if (!hasProof) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'กรุณาแนบหลักฐานกรรมสิทธิ์หรือสิทธิ์ให้เช่า',
                      ),
                    ),
                  );
                  return;
                }

                final dormId = 'dorm_${DateTime.now().millisecondsSinceEpoch}';
                final title = titleCtrl.text.trim();
                final location = addressCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final description = descriptionCtrl.text.trim();
                final imageUrl = imageUrlCtrl.text.trim();
                widget.consoleState.submitDormRequest(
                  sellerId: _currentSellerId,
                  sellerName: 'นายสมชาย ใจดี',
                  dormId: dormId,
                  dormName: title,
                  phone: phone,
                  location: location,
                  latitude: latitude,
                  longitude: longitude,
                  description: description,
                  priceMin: minPrice,
                  priceMax: maxPrice,
                  amenities: List<String>.from(amenities),
                  imageUrl: imageUrl,
                  documents: documents
                      .map((document) => Map<String, String>.from(document))
                      .toList(),
                );
                setState(
                  () => _myDorms.add({
                    'id': dormId,
                    'sellerId': _currentSellerId,
                    'title': title,
                    'location': location,
                    'latitude': latitude,
                    'longitude': longitude,
                    'phone': phone,
                    'description': description,
                    'priceMin': minPrice,
                    'priceMax': maxPrice,
                    'amenities': List<String>.from(amenities),
                    'imageUrl': imageUrl,
                    'approvalStatus': 'pending',
                    'roomsList': <RoomDetailModel>[],
                  }),
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ส่งข้อมูลและเอกสารให้แอดมินตรวจแล้ว หอจะยังไม่แสดงต่อผู้เช่าจนกว่าจะอนุมัติ',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('ส่งให้แอดมินตรวจ'),
            ),
          ],
        ),
      ),
    ).then((_) {
      titleCtrl.dispose();
      addressCtrl.dispose();
      latitudeCtrl.dispose();
      longitudeCtrl.dispose();
      phoneCtrl.dispose();
      descriptionCtrl.dispose();
      minPriceCtrl.dispose();
      maxPriceCtrl.dispose();
      imageUrlCtrl.dispose();
    });
  }

  // Modal สรุปและจัดการห้องพักทั้งหมดในหอนั้น
  void _showManageRoomsModal(Map<String, dynamic> dorm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final rooms = dorm['roomsList'] as List<RoomDetailModel>;
            final availCount = _getAvailableRoomsCount(dorm);
            final occCount = _getOccupiedRoomsCount(dorm);

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dorm['title'].toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ว่าง $availCount ห้อง • มีผู้เช่า $occCount ห้อง (รวม ${rooms.length} ห้อง)',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // 2. ปุ่มเพิ่มห้องพักในหอนี้
                      ElevatedButton.icon(
                        onPressed: () {
                          _showAddSingleRoomDialog(dorm, () {
                            setModalState(() {});
                            setState(() {});
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('เพิ่มห้อง'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: rooms.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.meeting_room_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'ยังไม่มีห้องพักในหอนี้ กดปุ่ม "+ เพิ่มห้อง"',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: rooms.length,
                            itemBuilder: (context, idx) {
                              final room = rooms[idx];
                              Color statusColor = Colors.green;
                              if (room.status == 'มีผู้เช่า')
                                statusColor = Colors.blue;
                              if (room.status == 'ปรับปรุง')
                                statusColor = Colors.red;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: statusColor
                                            .withOpacity(0.15),
                                        child: Text(
                                          room.roomNumber,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ห้อง ${room.roomNumber} (${room.roomType})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'ค่าเช่า: ฿${room.price.toStringAsFixed(0)} / เดือน',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 3. ปรับแก้เรื่องห้องว่างไม่ว่าง (Dropdown เลือกสถานะห้องได้ทันที)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: statusColor.withOpacity(0.4),
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: room.status,
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                              color: statusColor,
                                            ),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            items:
                                                [
                                                      'ว่าง',
                                                      'มีผู้เช่า',
                                                      'ปรับปรุง',
                                                    ]
                                                    .map(
                                                      (s) => DropdownMenuItem(
                                                        value: s,
                                                        child: Text(s),
                                                      ),
                                                    )
                                                    .toList(),
                                            onChanged: (newStatus) {
                                              if (newStatus != null) {
                                                setModalState(() {
                                                  rooms[idx] = RoomDetailModel(
                                                    roomNumber: room.roomNumber,
                                                    roomType: room.roomType,
                                                    price: room.price,
                                                    status: newStatus,
                                                  );
                                                });
                                                setState(() {});
                                              }
                                            },
                                          ),
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
          },
        );
      },
    );
  }

  // 2. Dialog สำหรับการเพิ่มห้องใหม่ลงในหอพัก
  void _showAddSingleRoomDialog(
    Map<String, dynamic> dorm,
    VoidCallback onAdded,
  ) {
    if (widget.consoleState.isSellerSuspended(
      dorm['sellerId']?.toString() ?? _currentSellerId,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บัญชีถูกระงับ จึงส่งคำขอเพิ่มห้องไม่ได้'),
        ),
      );
      return;
    }
    final roomNumCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String roomType = 'เตียง 5 ฟุต';
    String status = 'ว่าง';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('เพิ่มห้องพักใหม่ (${dorm['title']})'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: roomNumCtrl,
                    decoration: const InputDecoration(
                      labelText: 'เลขห้อง * (เช่น 105)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: roomType,
                    decoration: const InputDecoration(labelText: 'ประเภทห้อง'),
                    items:
                        [
                              'เตียง 5 ฟุต',
                              'เตียง 6 ฟุต (VIP)',
                              'ห้องสตูดิโอ',
                              'ห้องสูท 2 ห้องนอน',
                            ]
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => roomType = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ราคาค่าเช่า (บาท/เดือน) *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'สถานะห้องเริ่มต้น',
                    ),
                    items: ['ว่าง', 'มีผู้เช่า', 'ปรับปรุง']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => status = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (roomNumCtrl.text.isNotEmpty) {
                    final parsedPrice = double.tryParse(priceCtrl.text);
                    if (parsedPrice == null || parsedPrice <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('กรุณาระบุค่าเช่ามากกว่า 0 บาท'),
                        ),
                      );
                      return;
                    }
                    final rooms = dorm['roomsList'] as List<RoomDetailModel>;
                    final roomNumber = roomNumCtrl.text.trim();
                    if (rooms.any((room) => room.roomNumber == roomNumber)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('เลขห้องนี้มีอยู่แล้ว')),
                      );
                      return;
                    }
                    rooms.add(
                      RoomDetailModel(
                        roomNumber: roomNumber,
                        roomType: roomType,
                        price: parsedPrice,
                        status: status,
                      ),
                    );
                    onAdded();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เพิ่มห้อง $roomNumber แล้ว')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard เจ้าของหอพัก'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.deepOrange,
                    child: Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'คุณสมชาย ใจดี (เจ้าของหอ)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'โทร: 081-234-5678',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ยืนยันตัวตน KYC แล้ว ✓',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_sellerSuspended)
            Card(
              color: Colors.red.shade50,
              child: const ListTile(
                leading: Icon(Icons.block, color: Colors.red),
                title: Text(
                  'บัญชีผู้ขายถูกระงับ',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'ไม่สามารถเพิ่มห้องหรือแก้ไขประกาศได้ กรุณาติดต่อแอดมิน',
                ),
              ),
            ),

          // Monthly Subscription Card (500 THB/month)
          Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.deepOrange.shade200, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.amber.shade800,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'แพ็กเกจรายเดือน (500฿/เดือน)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _isSubscribed
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isSubscribed ? 'ใช้งานได้' : 'หมดอายุ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isSubscribed
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'หมดอายุวันที่: ${_subExpiryDate.day}/${_subExpiryDate.month}/${_subExpiryDate.year}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showSubscriptionPaymentDialog,
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: const Text('ต่ออายุสมาชิก ฿500 / เดือน'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange,
                        side: const BorderSide(color: Colors.deepOrange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: Colors.deepOrange,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ยอดเข้าชมประกาศทั้งหมด',
                          style: TextStyle(color: Colors.black54),
                        ),
                        Text(
                          '${widget.consoleState.totalViews} ครั้ง',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      '${widget.consoleState.pendingDormCount} หอรอตรวจ',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header + Add Dorm Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายการหอพักของคุณ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _sellerSuspended ? null : _showAddDormDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('เพิ่มหอพัก'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List of Dormitories
          ..._myDorms.map((dorm) {
            final rooms = dorm['roomsList'] as List<RoomDetailModel>;
            final availableCount = _getAvailableRoomsCount(dorm);
            final String imgUrl = dorm['imageUrl'] ?? '';
            final dormId = dorm['id'].toString();
            final isApproved = widget.consoleState.isDormApproved(dormId);
            final isClosed = widget.consoleState.isDormClosed(dormId);
            final viewCount = widget.consoleState.dormViews[dormId] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        image: imgUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(imgUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imgUrl.isEmpty
                          ? const Icon(
                              Icons.home_work_rounded,
                              color: Colors.deepOrange,
                            )
                          : null,
                    ),
                    title: Text(
                      dorm['title'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${dorm['location']}\n${isApproved ? '' : 'รอแอดมินอนุมัติ • '}${rooms.length} ห้องพัก • ว่าง $availableCount ห้อง • เข้าชม $viewCount ครั้ง',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: 'แก้ไขประกาศ',
                          onPressed:
                              widget.consoleState.isSellerSuspended(
                                dorm['sellerId']?.toString() ??
                                    _currentSellerId,
                              )
                              ? null
                              : () => _showEditDormDialog(dorm),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.deepOrange,
                          ),
                        ),
                        IconButton(
                          tooltip: 'จัดการห้อง',
                          onPressed:
                              widget.consoleState.isSellerSuspended(
                                dorm['sellerId']?.toString() ??
                                    _currentSellerId,
                              )
                              ? null
                              : () => _showManageRoomsModal(dorm),
                          icon: const Icon(
                            Icons.meeting_room_rounded,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: Icon(
                      isClosed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: isClosed ? Colors.grey : Colors.green,
                    ),
                    title: Text(
                      !isApproved
                          ? 'รออนุมัติข้อมูลหอ'
                          : isClosed
                          ? 'ปิดประกาศชั่วคราว'
                          : 'ประกาศกำลังแสดง',
                    ),
                    subtitle: Text(
                      !isApproved
                          ? 'ผู้เช่าจะเห็นประกาศหลังแอดมินอนุมัติ'
                          : isClosed
                          ? 'ผู้เช่าจะไม่เห็นหอนี้ในหน้าค้นหา'
                          : 'ผู้เช่าสามารถค้นหาและเปิดดูประกาศได้',
                    ),
                    value: !isClosed,
                    activeColor: Colors.deepOrange,
                    onChanged:
                        (!isApproved ||
                            widget.consoleState.isSellerSuspended(
                              dorm['sellerId']?.toString() ?? _currentSellerId,
                            ))
                        ? null
                        : (isOpen) {
                            widget.consoleState.toggleDormClosed(
                              dormId,
                              !isOpen,
                            );
                            setState(() {});
                          },
                  ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: widget.consoleState,
            builder: (context, _) {
              final sellerIds = _myDorms
                  .map((dorm) => dorm['sellerId'])
                  .toSet();
              final requests = widget.consoleState.dormRequests
                  .where((request) => sellerIds.contains(request['sellerId']))
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'สถานะตรวจสอบหอพัก',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (requests.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.fact_check_outlined),
                        title: Text('ยังไม่มีคำขอใหม่'),
                      ),
                    ),
                  ...requests.map((request) {
                    final status = request['status'];
                    final approved = status == 'approved';
                    final rejected = status == 'rejected';
                    final color = approved
                        ? Colors.green
                        : rejected
                        ? Colors.red
                        : Colors.orange;
                    final label = approved
                        ? 'อนุมัติแล้ว'
                        : rejected
                        ? 'ไม่อนุมัติ'
                        : 'รอแอดมินตรวจเอกสาร';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          approved
                              ? Icons.check_circle_outline
                              : rejected
                              ? Icons.cancel_outlined
                              : Icons.pending_actions,
                          color: color,
                        ),
                        title: Text(request['dormName'].toString()),
                        subtitle: Text(
                          '${request['location']} • $label\n${(request['documents'] as List? ?? []).length} เอกสารแนบ',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'คำขอนัดดูห้อง',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.deepOrange,
                ),
              ),
              title: Text('ยังไม่มีคำขอนัด'),
              subtitle: Text('คำขอจากผู้เช่าจะแสดงในส่วนนี้'),
            ),
          ),
          const SizedBox(height: 16),

          // Boost Listing Option
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade700, Colors.deepPurple.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.yellow,
                  size: 40,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'เพิ่มยอดด้วยการดันประกาศ (Boost)!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'จ่ายเพิ่มเพื่อแสดงหอพักขึ้นอันดับแรกในหน้าแรก',
                        style: TextStyle(
                          color: Colors.purple.shade100,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'ซื้อแพ็กเกจดันประกาศ (Boost) เรียบร้อย!',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text(
                    'ดันประกาศ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
