import 'package:flutter/material.dart';

import '../models/admin_console_state.dart';
import '../theme/app_theme.dart';

/// รายงานที่ Tenant ส่งจากหน้ารายละเอียดหอพัก และบันทึกอยู่ใน MySQL
class AdminReportsView extends StatefulWidget {
  final AdminConsoleState consoleState;
  const AdminReportsView({super.key, required this.consoleState});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  String _filter = 'all';
  @override
  void initState() {
    super.initState();
    widget.consoleState.refreshReports();
  }

  Future<void> _openReport(Map<String, dynamic> report) async {
    final noteController = TextEditingController(
      text: report['adminNote']?.toString() ?? '',
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20, 8, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('รายละเอียดรายงาน', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                _line('หอพัก', report['dormName']),
                _line('ผู้ถูกรายงาน', report['ownerName']),
                _line('ผู้รายงาน', '${report['reporterName']} (${report['reporterEmail']})'),
                _line('เหตุผล', report['reason']),
                _line('วันที่รายงาน', report['createdAt']),
                const SizedBox(height: 8),
                const Text('รายละเอียดเพิ่มเติม', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(report['description']?.toString().isNotEmpty == true
                    ? report['description'].toString() : 'ไม่ได้ระบุรายละเอียดเพิ่มเติม'),
                const SizedBox(height: 14),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'บันทึกของ Admin (ถ้ามี)',
                    hintText: 'ระบุผลการตรวจสอบหรือหมายเหตุ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, 'dismissed'),
                    icon: const Icon(Icons.close), label: const Text('ไม่รับเรื่อง'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, 'reviewed'),
                    icon: const Icon(Icons.check), label: const Text('ตรวจสอบแล้ว'),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (action == null || !mounted) return;
    try {
      final saved = await widget.consoleState.updateReportStatus(
        '${report['id']}', action, adminNote: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved
            ? (action == 'reviewed' ? 'บันทึกว่าตรวจสอบแล้ว' : 'ปิดรายงานนี้แล้ว')
            : 'บันทึกสถานะไม่สำเร็จ กรุณาลองใหม่'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกสถานะรายงานไม่สำเร็จ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.consoleState,
    builder: (context, _) {
      final all = widget.consoleState.reports;
      final visible = all.where((r) => _filter == 'all' || r['status'] == _filter).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('รายงานจากผู้ใช้งาน (${all.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton(onPressed: widget.consoleState.refreshReports, icon: const Icon(Icons.refresh), tooltip: 'โหลดรายงานใหม่'),
        ]),
        Text('รอตรวจสอบ ${widget.consoleState.pendingReportCount} รายการ', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          _chip('ทั้งหมด', 'all'), _chip('รอตรวจสอบ', 'pending'),
          _chip('ตรวจสอบแล้ว', 'reviewed'), _chip('ไม่รับเรื่อง', 'dismissed'),
        ]),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          AppCard(padding: const EdgeInsets.all(28), child: Column(children: const [
            Icon(Icons.flag_outlined, size: 40, color: AppColors.muted),
            SizedBox(height: 8), Text('ไม่มีรายงานในหมวดนี้'),
          ]))
        else
          ...visible.map((r) {
            final pending = r['status'] == 'pending';
            final statusText = switch (r['status']) {
              'reviewed' => 'ตรวจสอบแล้ว',
              'dismissed' => 'ไม่รับเรื่อง',
              _ => 'รอตรวจสอบ',
            };
            return AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _openReport(r),
                leading: CircleAvatar(
                  backgroundColor: pending ? AppColors.warningSoft : AppColors.field,
                  child: Icon(Icons.flag_outlined, color: pending ? AppColors.warning : AppColors.muted),
                ),
                title: Text('${r['dormName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('เหตุผล: ${r['reason']}\nผู้รายงาน: ${r['reporterName']} • ${r['createdAt']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: StatusPill(statusText,
                  color: pending ? AppColors.warning : AppColors.muted,
                  background: pending ? AppColors.warningSoft : AppColors.field),
              ),
            );
          }),
      ]);
    },
  );

  Widget _chip(String label, String value) => ChoiceChip(
    label: Text(label), selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );

  Widget _line(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 105, child: Text(label, style: const TextStyle(color: AppColors.muted))),
      Expanded(child: Text(value?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
    ]),
  );
}
