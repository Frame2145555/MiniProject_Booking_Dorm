import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/admin_api_service.dart';
import '../theme/app_theme.dart';

/// เปิดดูเอกสารแนบของคำขอลงประกาศหอ (แอดมิน)
/// - รูปภาพ: แสดงในแอป ซูม/เลื่อนได้
/// - PDF: แอปเปิด PDF เองไม่ได้ จึงให้คัดลอกลิงก์ชั่วคราว (10 นาที) ไปวางในเบราว์เซอร์
Future<void> showDormDocumentViewer(
  BuildContext context,
  Map<String, dynamic> document,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DormDocumentViewer(document: document),
  );
}

class _DormDocumentViewer extends StatefulWidget {
  final Map<String, dynamic> document;

  const _DormDocumentViewer({required this.document});

  @override
  State<_DormDocumentViewer> createState() => _DormDocumentViewerState();
}

class _DormDocumentViewerState extends State<_DormDocumentViewer> {
  bool _loading = true;
  String? _error;
  String _mimeType = '';
  Uint8List? _bytes;
  String? _link;
  bool _loadingLink = false;

  int? get _documentId => int.tryParse('${widget.document['id']}');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _documentId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'เอกสารนี้ยังไม่ได้บันทึกบน server';
      });
      return;
    }
    try {
      final doc = await AdminApiService.getDormDocument(id);
      final dataUrl = doc['fileData']?.toString() ?? '';
      final comma = dataUrl.indexOf(',');
      final header = comma > 0 ? dataUrl.substring(0, comma) : '';
      final mime = doc['mimeType']?.toString() ??
          RegExp(r'^data:([^;]+)').firstMatch(header)?.group(1) ??
          '';
      final bytes = base64Decode(comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl);
      if (!mounted) return;
      setState(() {
        _mimeType = mime;
        _bytes = bytes;
        _loading = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'ไฟล์เอกสารเสียหาย อ่านไม่ได้';
        _loading = false;
      });
    }
  }

  Future<void> _copyLink() async {
    final id = _documentId;
    if (id == null || _loadingLink) return;
    setState(() => _loadingLink = true);
    try {
      final link = await AdminApiService.getDormDocumentLink(id);
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      setState(() => _link = link);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('คัดลอกลิงก์แล้ว วางในเบราว์เซอร์เพื่อเปิดไฟล์ (ใช้ได้ 10 นาที)'),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingLink = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.document['name']?.toString() ?? 'เอกสาร';
    final type = widget.document['type']?.toString() ?? '';
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (type.isNotEmpty)
            Text(
              type,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
        ],
      ),
      content: SizedBox(width: 560, height: 480, child: _body()),
      actions: [
        if (_bytes != null)
          TextButton.icon(
            onPressed: _loadingLink ? null : _copyLink,
            icon: const Icon(Icons.link),
            label: const Text('คัดลอกลิงก์เปิดในเบราว์เซอร์'),
          ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (_mimeType.startsWith('image/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFFF2F2F5),
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.memory(
                _bytes!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Text('แสดงรูปนี้ไม่ได้ ลองเปิดจากลิงก์แทน'),
              ),
            ),
          ),
        ),
      );
    }
    // PDF หรือไฟล์อื่น
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.picture_as_pdf_outlined,
            size: 64,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          Text(
            'ไฟล์ PDF ขนาด ${(_bytes!.length / 1024).toStringAsFixed(0)} KB',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'กด "คัดลอกลิงก์เปิดในเบราว์เซอร์" แล้ววางในแท็บใหม่เพื่อดูไฟล์',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          if (_link != null) ...[
            const SizedBox(height: 12),
            SelectableText(_link!, style: const TextStyle(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
