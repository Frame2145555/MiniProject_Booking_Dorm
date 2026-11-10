import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/admin_console_state.dart';
import '../models/dorm_model.dart';
import '../theme/app_theme.dart';
import '../widgets/dorm_gallery.dart';

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
            Icon(Icons.stars_rounded, color: AppColors.ink),
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
                  color: AppColors.field,
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
              backgroundColor: AppColors.success,
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
    // สำเนารูปเพิ่มเติม: แก้ไขได้อิสระ แล้วค่อยบันทึกกลับเมื่อกด "บันทึก"
    final galleryImages = List<dynamic>.from(
      (dorm['images'] as List?) ?? const [],
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: AppColors.ink),
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
                decoration: AppInputs.field(labelText: 'ชื่อหอพัก'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: AppInputs.field(labelText: 'ที่อยู่ / ทำเล'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: AppInputs.field(
                  labelText: 'เบอร์ติดต่อผู้ดูแลหอ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: AppInputs.field(labelText: 'รายละเอียดหอพัก'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: AppInputs.field(
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
                      decoration: AppInputs.field(
                        labelText: 'ค่าเช่าสูงสุด',
                        prefixText: '฿',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageController,
                decoration: AppInputs.field(labelText: 'URL รูปหน้าปก'),
              ),
              const SizedBox(height: 16),
              DormGalleryEditor(images: galleryImages),
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
                dorm['images'] = List<dynamic>.from(galleryImages);
              });
              widget.consoleState.updateDormMedia(
                dorm['id'].toString(),
                imageUrl: imageController.text.trim(),
                images: List<dynamic>.from(galleryImages),
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('อัปเดตข้อมูลตัวอย่างแล้ว')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
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
    final galleryImages = <dynamic>[];
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
              Icon(Icons.add_business_rounded, color: AppColors.ink),
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
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                                    TextField(
                    controller: titleCtrl,
                    decoration: AppInputs.field(
                      labelText: 'ชื่อหอพัก *',
                      prefixIcon: Icon(Icons.apartment),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: AppInputs.field(
                      labelText: 'ที่อยู่เต็ม / ทำเล *',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'พิกัดหอพัก (ถ้ามี): เปิด Google Maps ที่หอ กดค้างบนจุดหอ แล้วคัดลอกตัวเลขคู่ เช่น 13.7563, 100.5018',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                          decoration: AppInputs.field(
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
                          decoration: AppInputs.field(
                            labelText: 'ลองจิจูด',
                            hintText: '100.5018',
                            prefixIcon: Icon(Icons.explore_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: AppInputs.field(
                      labelText: 'เบอร์ติดต่อผู้ดูแลหอ *',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionCtrl,
                    maxLines: 3,
                    decoration: AppInputs.field(
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
                          decoration: AppInputs.field(
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
                          decoration: AppInputs.field(
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
                            selectedColor: AppColors.accentSoft,
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlCtrl,
                    decoration: AppInputs.field(
                      labelText: 'ลิงก์รูปหน้าปก (ถ้ามี)',
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DormGalleryEditor(images: galleryImages),
                  const SizedBox(height: 16),
                  const Text(
                    'เอกสารประกอบการลงหอ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'จำเป็น: หลักฐานกรรมสิทธิ์หรือสิทธิ์ให้เช่า เช่น โฉนด สัญญาเช่า หรือหนังสือมอบอำนาจ',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                        color: AppColors.success,
                      ),
                      title: Text(document['name'] ?? ''),
                      subtitle: Text(
                        document['type'] == 'proof_of_right'
                            ? 'หลักฐานสิทธิ์ให้เช่า • จำเป็น'
                            : 'ใบอนุญาต/ทะเบียนธุรกิจ',
                      ),
                      trailing: IconButton(
                        tooltip: 'นำเอกสารออก',
                        icon: const Icon(Icons.close, color: AppColors.danger),
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
                  images: List<dynamic>.from(galleryImages),
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
                    'images': List<dynamic>.from(galleryImages),
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
                backgroundColor: AppColors.ink,
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
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                              color: AppColors.muted,
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
                          backgroundColor: AppColors.ink,
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
                                  color: AppColors.muted,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'ยังไม่มีห้องพักในหอนี้ กดปุ่ม "+ เพิ่มห้อง"',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: rooms.length,
                            itemBuilder: (context, idx) {
                              final room = rooms[idx];
                              Color statusColor = AppColors.success;
                              if (room.status == 'มีผู้เช่า')
                                statusColor = AppColors.info;
                              if (room.status == 'ปรับปรุง')
                                statusColor = AppColors.danger;

                              return AppCard(
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
                                                color: AppColors.muted,
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
                    decoration: AppInputs.field(
                      labelText: 'เลขห้อง * (เช่น 105)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: roomType,
                    decoration: AppInputs.field(labelText: 'ประเภทห้อง'),
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
                    decoration: AppInputs.field(
                      labelText: 'ราคาค่าเช่า (บาท/เดือน) *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: AppInputs.field(
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
                  backgroundColor: AppColors.ink,
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

  // ───────────────────────── UI helpers (Owner) ─────────────────────────

  Widget _sectionHeader(String title, {String? subtitle, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _metaChip(
    IconData icon,
    String text, {
    Color color = AppColors.ink,
    Color background = AppColors.field,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(IconData icon, String title, String? subtitle) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _heroDivider() => Container(
    width: 1,
    height: 52,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Colors.white.withOpacity(0.14),
  );

  Widget _buildHero() {
    final totalAvailable = _myDorms.fold<int>(
      0,
      (sum, dorm) => sum + _getAvailableRoomsCount(dorm),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.dark,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'คุณสมชาย ใจดี (เจ้าของหอ)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'โทร: 081-234-5678',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    SizedBox(height: 8),
                    StatusPill(
                      'ยืนยันตัวตน KYC แล้ว ✓',
                      color: AppColors.success,
                      background: AppColors.successSoft,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _heroStat(
                    Icons.visibility_outlined,
                    '${widget.consoleState.totalViews}',
                    'ยอดเข้าชมประกาศทั้งหมด',
                  ),
                ),
                _heroDivider(),
                Expanded(
                  child: _heroStat(
                    Icons.pending_actions_rounded,
                    '${widget.consoleState.pendingDormCount}',
                    'หอรอตรวจ',
                  ),
                ),
                _heroDivider(),
                Expanded(
                  child: _heroStat(
                    Icons.meeting_room_outlined,
                    '$totalAvailable',
                    'ห้องว่างรวม',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspendedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, color: AppColors.danger),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'บัญชีผู้ขายถูกระงับ',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'ไม่สามารถเพิ่มห้องหรือแก้ไขประกาศได้ กรุณาติดต่อแอดมิน',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Monthly Subscription Card (500 THB/month)
  Widget _buildSubscriptionCard() {
    final daysLeft = _isSubscribed
        ? _subExpiryDate.difference(DateTime.now()).inDays.clamp(0, 30).toInt()
        : 0;
    final progress = daysLeft / 30;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.warning,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'แพ็กเกจรายเดือน (500฿/เดือน)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'หมดอายุวันที่: ${_subExpiryDate.day}/${_subExpiryDate.month}/${_subExpiryDate.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                _isSubscribed ? 'ใช้งานได้' : 'หมดอายุ',
                color: _isSubscribed ? AppColors.success : AppColors.danger,
                background: _isSubscribed
                    ? AppColors.successSoft
                    : AppColors.dangerSoft,
              ),
            ],
          ),
          if (_isSubscribed) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.field,
                color: daysLeft <= 7 ? AppColors.warning : AppColors.success,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'เหลืออีก $daysLeft วัน',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showSubscriptionPaymentDialog,
              icon: const Icon(Icons.payment_rounded, size: 18),
              label: const Text('ต่ออายุสมาชิก ฿500 / เดือน'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDormCard(Map<String, dynamic> dorm) {
    final rooms = dorm['roomsList'] as List<RoomDetailModel>;
    final availableCount = _getAvailableRoomsCount(dorm);
    final occupiedCount = _getOccupiedRoomsCount(dorm);
    final String imgUrl = dorm['imageUrl'] ?? '';
    final dormId = dorm['id'].toString();
    final isApproved = widget.consoleState.isDormApproved(dormId);
    final isClosed = widget.consoleState.isDormClosed(dormId);
    final viewCount = widget.consoleState.dormViews[dormId] ?? 0;
    final sellerSuspended = widget.consoleState.isSellerSuspended(
      dorm['sellerId']?.toString() ?? _currentSellerId,
    );

    final String statusLabel = !isApproved
        ? 'รออนุมัติ'
        : isClosed
        ? 'ปิดประกาศชั่วคราว'
        : 'กำลังแสดง';
    final Color statusColor = !isApproved
        ? AppColors.warning
        : isClosed
        ? AppColors.muted
        : AppColors.success;
    final Color statusBg = !isApproved
        ? AppColors.warningSoft
        : isClosed
        ? AppColors.field
        : AppColors.successSoft;

    final Widget placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.coverFor(dorm['title'].toString()),
      ),
      child: Center(
        child: Icon(
          Icons.home_work_rounded,
          size: 64,
          color: Colors.white.withOpacity(0.16),
        ),
      ),
    );

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 136,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imgUrl.isNotEmpty
                    ? Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => placeholder,
                      )
                    : placeholder,
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.3, 1],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.65),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: StatusPill(
                    statusLabel,
                    color: statusColor,
                    background: statusBg,
                  ),
                ),
                if (dorm['priceMin'] != null && dorm['priceMax'] != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '฿${dorm['priceMin']} - ฿${dorm['priceMax']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dorm['title'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              dorm['location'].toString(),
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaChip(
                      Icons.meeting_room_outlined,
                      '${rooms.length} ห้องพัก',
                    ),
                    _metaChip(
                      Icons.check_circle_outline,
                      'ว่าง $availableCount ห้อง',
                      color: AppColors.success,
                      background: AppColors.successSoft,
                    ),
                    _metaChip(
                      Icons.visibility_outlined,
                      'เข้าชม $viewCount ครั้ง',
                    ),
                  ],
                ),
                if (!isApproved) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'รอแอดมินอนุมัติ • ผู้เช่าจะเห็นประกาศหลังแอดมินอนุมัติ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (rooms.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'อัตราเข้าพัก',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const Spacer(),
                      Text(
                        'มีผู้เช่า $occupiedCount / ${rooms.length} ห้อง',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: occupiedCount / rooms.length,
                      minHeight: 7,
                      backgroundColor: AppColors.field,
                      color: AppColors.ink,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sellerSuspended
                            ? null
                            : () => _showEditDormDialog(dorm),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('แก้ไขประกาศ'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: sellerSuspended
                            ? null
                            : () => _showManageRoomsModal(dorm),
                        icon: const Icon(Icons.meeting_room_rounded, size: 18),
                        label: const Text('จัดการห้อง'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: Icon(
              isClosed
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: isClosed ? AppColors.muted : AppColors.success,
            ),
            title: Text(
              !isApproved
                  ? 'รออนุมัติข้อมูลหอ'
                  : isClosed
                  ? 'ปิดประกาศชั่วคราว'
                  : 'ประกาศกำลังแสดง',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              !isApproved
                  ? 'ผู้เช่าจะเห็นประกาศหลังแอดมินอนุมัติ'
                  : isClosed
                  ? 'ผู้เช่าจะไม่เห็นหอนี้ในหน้าค้นหา'
                  : 'ผู้เช่าสามารถค้นหาและเปิดดูประกาศได้',
              style: const TextStyle(color: AppColors.muted),
            ),
            value: !isClosed,
            activeColor: AppColors.ink,
            onChanged: (!isApproved || sellerSuspended)
                ? null
                : (isOpen) {
                    widget.consoleState.toggleDormClosed(dormId, !isOpen);
                    setState(() {});
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStatusSection() {
    final sellerIds = _myDorms.map((dorm) => dorm['sellerId']).toSet();
    final requests = widget.consoleState.dormRequests
        .where((request) => sellerIds.contains(request['sellerId']))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('สถานะตรวจสอบหอพัก'),
        if (requests.isEmpty)
          _emptyCard(Icons.fact_check_outlined, 'ยังไม่มีคำขอใหม่', null),
        ...requests.map((request) {
          final status = request['status'];
          final approved = status == 'approved';
          final rejected = status == 'rejected';
          final color = approved
              ? AppColors.success
              : rejected
              ? AppColors.danger
              : AppColors.warning;
          final background = approved
              ? AppColors.successSoft
              : rejected
              ? AppColors.dangerSoft
              : AppColors.warningSoft;
          final label = approved
              ? 'อนุมัติแล้ว'
              : rejected
              ? 'ไม่อนุมัติ'
              : 'รอแอดมินตรวจเอกสาร';
          final docCount = (request['documents'] as List? ?? []).length;
          return AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    approved
                        ? Icons.check_circle_outline
                        : rejected
                        ? Icons.cancel_outlined
                        : Icons.pending_actions,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['dormName'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request['location'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatusPill(label, color: color, background: background),
                          const SizedBox(width: 8),
                          Text(
                            '$docCount เอกสารแนบ',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Boost Listing Option
  Widget _buildBoostBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ink, Color(0xFF4A3F8C)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.dark,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 28,
            ),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'จ่ายเพิ่มเพื่อแสดงหอพักขึ้นอันดับแรกในหน้าแรก',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ซื้อแพ็กเกจดันประกาศ (Boost) เรียบร้อย!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text(
              'ดันประกาศ',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AnimatedBuilder(
        animation: widget.consoleState,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _buildHero(),
              const SizedBox(height: 16),
              if (_sellerSuspended) _buildSuspendedBanner(),
              _buildSubscriptionCard(),
              const SizedBox(height: 24),
              _sectionHeader(
                'รายการหอพักของคุณ',
                subtitle: '${_myDorms.length} หอพัก',
                trailing: ElevatedButton.icon(
                  onPressed: _sellerSuspended ? null : _showAddDormDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('เพิ่มหอพัก'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              ..._myDorms.map(_buildDormCard),
              const SizedBox(height: 8),
              _buildReviewStatusSection(),
              const SizedBox(height: 20),
              _sectionHeader('คำขอนัดดูห้อง'),
              _emptyCard(
                Icons.calendar_month_rounded,
                'ยังไม่มีคำขอนัด',
                'คำขอจากผู้เช่าจะแสดงในส่วนนี้',
              ),
              const SizedBox(height: 20),
              _buildBoostBanner(),
            ],
          );
        },
      ),
    );
  }
}
