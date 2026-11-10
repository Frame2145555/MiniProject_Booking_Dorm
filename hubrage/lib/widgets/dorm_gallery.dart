import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

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
    return Image.network(
      source.toString(),
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

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      if (missing > 0) _toast('อ่านไฟล์รูปไม่สำเร็จ ลองเพิ่มจากลิงก์แทน');
    } catch (_) {
      if (mounted) _toast('เปิดตัวเลือกรูปภาพไม่สำเร็จ');
    }
  }

  Future<void> _addFromLink() async {
    if (_full) return _toast('เพิ่มรูปได้สูงสุด ${widget.maxImages} รูป');
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('เพิ่มรูปจากลิงก์'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: AppInputs.field(labelText: 'ลิงก์รูป (https://...)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return _toast('ลิงก์ต้องขึ้นต้นด้วย http:// หรือ https://');
    }
    setState(() => widget.images.add(url));
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
        if (images.isNotEmpty)
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Stack(
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
            ),
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
            OutlinedButton.icon(
              onPressed: _full ? null : _addFromLink,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('เพิ่มจากลิงก์'),
            ),
          ],
        ),
      ],
    );
  }
}