import 'package:flutter/material.dart';

import '../services/owner_api_service.dart';
import '../theme/app_theme.dart';

/// รายได้ของเจ้าของหอ (จาก GET /api/owner/revenue)
/// นับเฉพาะการจองที่เจ้าของหอกด "ยืนยัน" แล้ว (completed)
/// ส่วน "รอยืนยัน" คือแอดมินตรวจเงินแล้วแต่เจ้าของหอยังไม่กดยืนยัน ยังไม่นับเป็นรายได้
class OwnerRevenueSection extends StatefulWidget {
  /// เปลี่ยนค่านี้เมื่อต้องการให้โหลดใหม่ (หน้าเจ้าของหอเพิ่มค่าทุกครั้งที่โหลดข้อมูลใหม่)
  final int reloadKey;

  const OwnerRevenueSection({super.key, this.reloadKey = 0});

  @override
  State<OwnerRevenueSection> createState() => _OwnerRevenueSectionState();
}

class _OwnerRevenueSectionState extends State<OwnerRevenueSection> {
  static const _months = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  int? _year;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OwnerRevenueSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await OwnerApiService.getRevenue(year: _year);
      if (!mounted) return;
      final data = Map<String, dynamic>.from(response['data'] as Map);
      setState(() {
        _data = data;
        _year = _n(data['year']).toInt();
      });
    } on OwnerApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดข้อมูลรายได้ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  num _n(dynamic value) =>
      value is num ? value : (num.tryParse('$value') ?? 0);

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];

  /// 12500 -> ฿12,500
  String _baht(num value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '฿$buffer';
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return '';
    return '${parsed.day} ${_months[parsed.month - 1]} ${parsed.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        if (data == null)
          (_loading
              ? const LinearProgressIndicator()
              : const SizedBox.shrink())
        else ...[
          _buildToolbar(data),
          const SizedBox(height: 8),
          _buildSummary(data),
          const SizedBox(height: 8),
          _buildMonthChart(data),
          const SizedBox(height: 8),
          _buildByDorm(data),
          const SizedBox(height: 8),
          _buildRecent(data),
        ],
      ],
    );
  }

  Widget _buildToolbar(Map<String, dynamic> data) {
    final years = data['years'] is List
        ? (data['years'] as List).map((y) => _n(y).toInt()).toList()
        : <int>[];
    final current = _year ?? DateTime.now().year;
    if (!years.contains(current)) years.add(current);
    return Row(
      children: [
        const Text('ปี', style: TextStyle(color: AppColors.muted)),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: current,
          underline: const SizedBox.shrink(),
          items: years
              .map(
                (y) => DropdownMenuItem(value: y, child: Text('${y + 543}')),
              )
              .toList(),
          onChanged: _loading
              ? null
              : (y) {
                  if (y == null) return;
                  _year = y;
                  _load();
                },
        ),
        const Spacer(),
        if (_loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        IconButton(
          tooltip: 'โหลดรายได้ใหม่',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    String sub, {
    Color color = AppColors.ink,
  }) {
    return Expanded(
      child: AppCard(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(Map<String, dynamic> data) {
    final year = _n(data['year']).toInt() + 543;
    return Column(
      children: [
        Row(
          children: [
            _statCard(
              'รายได้ปี $year',
              _baht(_n(data['yearRevenue'])),
              '${_n(data['yearCount']).toInt()} การจอง',
              color: AppColors.success,
            ),
            _statCard(
              'รายได้ทั้งหมด',
              _baht(_n(data['totalRevenue'])),
              '${_n(data['completedCount']).toInt()} การจอง',
            ),
          ],
        ),
        Row(
          children: [
            _statCard(
              'รอคุณยืนยัน',
              _baht(_n(data['pendingAmount'])),
              '${_n(data['pendingCount']).toInt()} รายการ (ยังไม่นับเป็นรายได้)',
              color: AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthChart(Map<String, dynamic> data) {
    final months = _list(data['byMonth']);
    final values = months.map((m) => _n(m['revenue'])).toList();
    final maxValue = values.isEmpty
        ? 0
        : values.reduce((a, b) => a > b ? a : b);
    const chartHeight = 100.0;
    return AppCard(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายได้รายเดือน',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: chartHeight + 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(months.length, (i) {
                final value = values[i];
                final double barHeight = maxValue == 0
                    ? 2.0
                    : (chartHeight * value / maxValue)
                          .clamp(2.0, chartHeight)
                          .toDouble();
                return Expanded(
                  child: Tooltip(
                    message: '${_months[i]}: ${_baht(value)}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (value > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              value >= 1000
                                  ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'
                                  : '${value.round()}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: barHeight,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: value > 0
                                ? AppColors.accent
                                : AppColors.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _months[i],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildByDorm(Map<String, dynamic> data) {
    final dorms = _list(data['byDorm']);
    return AppCard(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายได้แยกตามหอพัก (ปีที่เลือก)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (dorms.isEmpty)
            const Text(
              'ยังไม่มีหอพัก',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            )
          else
            ...dorms.map(
              (dorm) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${dorm['dormName']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_n(dorm['count']).toInt()} การจอง',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _baht(_n(dorm['revenue'])),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecent(Map<String, dynamic> data) {
    final recent = _list(data['recent']);
    return AppCard(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายการล่าสุดที่ยืนยันแล้ว',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            const Text(
              'ยังไม่มีรายได้ (รายได้จะขึ้นเมื่อคุณกดยืนยันการจองที่แอดมินตรวจเงินแล้ว)',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            )
          else
            ...recent.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['dormName']} • ห้อง ${item['roomNumber']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item['tenantName']} • ${item['planLabel']} • ${_date(item['confirmedAt'])}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _baht(_n(item['amount'])),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
