import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../theme/app_theme.dart';

/// รูปในแกลเลอรีหอพัก: เก็บเป็น String (ลิงก์รูป) หรือ Uint8List (ไฟล์ที่เลือกจากเครื่อง)
class DormGalleryImage extends StatelessWidget {
  final dynamic source;
  final BoxFit fit;
  const DormGalleryImage(this.source, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final broken = Container(
      color: AppColors.field,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
    );
    if (source is Uint8List) {
      return Image.memory(
        source as Uint8List,
        fit: fit,
        errorBuilder: (_, __, ___) => broken,
      );
    }
    // รูปที่อัปโหลดขึ้น server เก็บเป็น /uploads/... -> ต่อหน้า baseUrl ให้เป็นลิงก์เต็ม
    final text = source.toString();
    return Image.network(
      text.startsWith('/') ? '${ApiConfig.baseUrl}$text' : text,
      fit: fit,
      errorBuilder: (_, __, ___) => broken,
    );
  }
}

/// ตัวจัดการรูปเพิ่มเติมของหอพัก (นอกเหนือจากรูปหน้าปก)
/// แก้ไขรายการ [images] ที่ส่งเข้ามาโดยตรง (ไม่ต้องใช้ setState จากภายนอก)
class DormGalleryEditor extends StatefulWidget {
  final List<dynamic> images;
  final int maxImages;

  const DormGalleryEditor({super.key, required this.images, this.maxImages = 10});

  @override
  State<DormGalleryEditor> createState() => _DormGalleryEditorState();
}

class _DormGalleryEditorState extends State<DormGalleryEditor> {
  bool get _full => widget.images.length >= widget.maxImages;

  // แสดงข้อความในกล่องเลย (SnackBar จะถูกหน้าต่างฟอร์มบังอยู่ จึงมองไม่เห็น)
  String? _message;

  void _toast(String message) {
    if (mounted) setState(() => _message = message);
  }

  /// PlatformFile ของ file_picker เวอร์ชันนี้ไม่มี getter `bytes` จึงลองอ่านทีละวิธีแบบ dynamic
  /// (xFile → readStream → path) วิธีไหนใช้ไม่ได้จะข้ามไปวิธีถัดไป
  Future<dynamic> _readImage(dynamic file) async {
    try {
      final data = await file.xFile.readAsBytes();
      if (data is Uint8List && data.isNotEmpty) return data;
    } catch (_) {}
    try {
      final Stream<List<int>>? stream = file.readStream;
      if (stream != null) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in stream) {
          builder.add(chunk);
        }
        if (builder.length > 0) return builder.toBytes();
      }
    } catch (_) {}
    try {
      // บนเว็บ path เป็น blob URL ใช้กับ Image.network ได้
      final String? path = file.path;
      if (kIsWeb && path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return null;
  }

  Future<void> _pickFromDevice() async {
    if (_full) return _toast('เพิ่มรูปได้สูงสุด ${widget.maxImages} รูป');
    _message = null;
    try {
      // file_picker 13.3.2: pickFiles ไม่มีพารามิเตอร์ allowMultiple/withData
      // จึงเลือกทีละรูป (กดปุ่มซ้ำเพื่อเพิ่มรูปถัดไป)
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      var missing = 0;
      for (final file in files) {
        if (_full) break;
        final image = await _readImage(file);
        if (image == null) {
          missing++;
        } else {
          widget.images.add(image);
        }
      }
      if (mounted) setState(() {});
      if (missing > 0) _toast('อ่านไฟล์รูปไม่สำเร็จ กรุณาลองเลือกรูปอีกครั้ง');
    } catch (_) {
      if (mounted) _toast('เปิดตัวเลือกรูปภาพไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'รูปภาพเพิ่มเติม',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${images.length}/${widget.maxImages}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'เพิ่มรูปห้อง/ส่วนกลางได้หลายรูป นอกเหนือจากรูปหน้าปก',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        // ใช้ Wrap (ขึ้นบรรทัดใหม่เอง) แทน ListView แนวนอน:
        // ตัวแก้ไขนี้อยู่ใน AlertDialog ซึ่งต้องถามความกว้างของเนื้อหาก่อน (intrinsic width)
        // ListView ตอบคำถามนี้ไม่ได้ -> layout พัง -> pop up กลายเป็นกล่องขาวทันทีที่มีรูปแรก
        if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (var i = 0; i < images.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: DormGalleryImage(images[i]),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => setState(() => images.removeAt(i)),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        if (images.isNotEmpty) const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _full ? null : _pickFromDevice,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('เลือกรูปจากเครื่อง'),
            ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// ต่อหน้า baseUrl ให้รูปที่อัปโหลดขึ้น server (เก็บเป็น /uploads/...) ใช้กับ Image.network ได้
String resolveImageUrl(String url) =>
    url.startsWith('/') ? '${ApiConfig.baseUrl}$url' : url;

/// อ่านไบต์ของรูปที่เลือกจาก file_picker (ลองทีละวิธี วิธีไหนใช้ไม่ได้ข้ามไปวิธีถัดไป)
Future<dynamic> _readPickedImage(dynamic file) async {
  try {
    final data = await file.xFile.readAsBytes();
    if (data is Uint8List && data.isNotEmpty) return data;
  } catch (_) {}
  try {
    final Stream<List<int>>? stream = file.readStream;
    if (stream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      if (builder.length > 0) return builder.toBytes();
    }
  } catch (_) {}
  try {
    final String? path = file.path;
    if (kIsWeb && path != null && path.isNotEmpty) return path;
  } catch (_) {}
  return null;
}

/// ตัวเลือกรูปหน้าปกหอพัก: เลือกได้ 1 รูปจากเครื่องเท่านั้น (ไม่มีช่องกรอกลิงก์)
/// [cover].value = null (ไม่มีรูป) | String (รูปเดิมที่บันทึกไว้) | Uint8List (รูปที่เพิ่งเลือก)
class DormCoverEditor extends StatefulWidget {
  final ValueNotifier<dynamic> cover;
  const DormCoverEditor({super.key, required this.cover});

  @override
  State<DormCoverEditor> createState() => _DormCoverEditorState();
}

class _DormCoverEditorState extends State<DormCoverEditor> {
  String? _message;

  Future<void> _pick() async {
    setState(() => _message = null);
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final image = await _readPickedImage(files.first);
      if (image == null) {
        if (mounted) {
          setState(() => _message = 'อ่านไฟล์รูปไม่สำเร็จ กรุณาลองเลือกรูปอีกครั้ง');
        }
        return;
      }
      widget.cover.value = image;
    } catch (_) {
      if (mounted) setState(() => _message = 'เปิดตัวเลือกรูปภาพไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: widget.cover,
      builder: (context, value, _) {
        final hasCover = value != null && !(value is String && value.isEmpty);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รูปหน้าปก',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'รูปที่แสดงบนการ์ดหอพักในหน้าแรกและหน้าค้นหา',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (hasCover) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 160,
                      height: 100,
                      child: DormGalleryImage(value),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => widget.cover.value = null,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(hasCover ? 'เปลี่ยนรูปหน้าปก' : 'เลือกรูปหน้าปกจากเครื่อง'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(
                _message!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }
}