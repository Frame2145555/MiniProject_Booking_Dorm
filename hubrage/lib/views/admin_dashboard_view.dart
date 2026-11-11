import 'package:flutter/material.dart';

import '../models/admin_console_state.dart';
import '../models/kyc_request_model.dart';
import '../theme/app_theme.dart';
import 'admin_kyc_detail_view.dart';

class AdminDashboardView extends StatefulWidget {
  final AdminConsoleState consoleState;

  const AdminDashboardView({super.key, required this.consoleState});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  int _selectedSection = 0;

  final List<KYCRequestModel> _kycList = [
    KYCRequestModel(
      id: 'KYC-001',
      sellerName: 'นายสมชาย ใจดี',
      dormName: 'หอรวย เธะ (รามคำแหง 24)',
      phone: '081-234-5678',
      email: 'somchai@email.com',
      idCardNumber: '1-1002-34567-89-0',
      submissionDate: '06 พ.ย. 2026',
      status: 'pending',
    ),
    KYCRequestModel(
      id: 'KYC-002',
      sellerName: 'นางสาววิภาวดี รุ่งเรือง',
      dormName: 'กรีนวิลล์ คอนโดเช่า',
      phone: '089-876-5432',
      email: 'wipawadee@email.com',
      idCardNumber: '3-4501-98765-43-2',
      submissionDate: '05 พ.ย. 2026',
      status: 'pending',
    ),
  ];

  Future<void> _showSellerDetails(Map<String, dynamic> seller) async {
    final suspended = seller['status'] == 'suspended';
    final sellerViews =
        widget.consoleState.dormViews[seller['dormId']] ?? seller['views'];
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.field,
                    child: const Icon(Icons.store, color: AppColors.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seller['name'].toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          seller['status'] == 'active'
                              ? 'บัญชีกำลังใช้งาน'
                              : 'บัญชีถูกระงับ',
                          style: TextStyle(
                            color: suspended ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _detail(
                'อีเมล',
                seller['email'].toString(),
                Icons.email_outlined,
              ),
              _detail(
                'โทรศัพท์',
                seller['phone'].toString(),
                Icons.call_outlined,
              ),
              _detail(
                'หอพัก',
                seller['dorm'].toString(),
                Icons.apartment_outlined,
              ),
              _detail(
                'สถานะ KYC',
                seller['kyc'] == 'verified' ? 'ยืนยันแล้ว' : 'รอตรวจสอบ',
                Icons.verified_user_outlined,
              ),
              _detail(
                'สมัครเมื่อ',
                seller['joined'].toString(),
                Icons.calendar_today_outlined,
              ),
              _detail(
                'เข้าใช้งานล่าสุด',
                seller['lastActive'].toString(),
                Icons.access_time,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      'เข้าชมประกาศ',
                      '$sellerViews',
                      Icons.visibility_outlined,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      'ห้องทั้งหมด',
                      '${seller['rooms']}',
                      Icons.meeting_room_outlined,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      'การจอง',
                      '${seller['bookings']}',
                      Icons.event_available_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _detail(
                'รายงานจากผู้ใช้',
                '${seller['reports']} รายการ',
                Icons.flag_outlined,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    suspended ? 'activate' : 'suspend',
                  ),
                  icon: Icon(
                    suspended ? Icons.lock_open_outlined : Icons.block,
                    color: suspended ? AppColors.success : AppColors.danger,
                  ),
                  label: Text(
                    suspended ? 'คืนสถานะบัญชี' : 'ระงับบัญชีผู้ขาย',
                    style: TextStyle(
                      color: suspended ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    final suspend = action == 'suspend';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspend ? 'ยืนยันการระงับบัญชี' : 'คืนสถานะบัญชี'),
        content: Text(
          suspend
              ? 'ระงับบัญชี ${seller['name']} หรือไม่? ผู้ขายจะเข้าใช้งานและจัดการประกาศไม่ได้'
              : 'เปิดใช้งานบัญชี ${seller['name']} อีกครั้งหรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed == true)
      widget.consoleState.suspendSeller(seller['id'].toString(), suspend);
  }

  Future<void> _showDormRequest(Map<String, dynamic> request) async {
    final documents = List<Map<String, dynamic>>.from(
      request['documents'] ?? const [],
    );
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตรวจสอบคำขอลงประกาศหอ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail(
                'เจ้าของหอ',
                request['sellerName'].toString(),
                Icons.person_outline,
              ),
              _detail(
                'ชื่อหอ',
                request['dormName'].toString(),
                Icons.apartment_outlined,
              ),
              _detail(
                'เบอร์โทร',
                request['phone'].toString(),
                Icons.call_outlined,
              ),
              _detail(
                'ที่อยู่',
                request['location'].toString(),
                Icons.location_on_outlined,
              ),
              if (request['latitude'] != null && request['longitude'] != null)
                _detail(
                  'พิกัด',
                  '${request['latitude']}, ${request['longitude']}',
                  Icons.my_location_outlined,
                ),
              _detail(
                'ช่วงราคา',
                '฿${request['priceMin']} - ฿${request['priceMax']} / เดือน',
                Icons.payments_outlined,
              ),
              _detail(
                'วันที่ส่ง',
                request['submittedAt'].toString(),
                Icons.schedule,
              ),
              const SizedBox(height: 8),
              const Text(
                'รายละเอียดหอ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(request['description']?.toString() ?? '—'),
              const SizedBox(height: 12),
              const Text(
                'เอกสารแนบ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (documents.isEmpty)
                const Text(
                  'ไม่พบเอกสารแนบ',
                  style: TextStyle(color: AppColors.danger),
                ),
              ...documents.map(
                (document) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppColors.ink,
                  ),
                  title: Text(document['type']?.toString() ?? 'เอกสาร'),
                  subtitle: Text(
                    document['name']?.toString() ??
                        document['reference']?.toString() ??
                        '',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('ปิด'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ปฏิเสธ', style: TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton(
            onPressed: documents.isEmpty
                ? null
                : () => Navigator.pop(context, true),
            child: const Text('อนุมัติหอ'),
          ),
        ],
      ),
    );
    if (decision != null) {
      widget.consoleState.reviewDormRequest(
        request['id'].toString(),
        approve: decision,
      );
    }
  }

  // ───────────────────────── UI (Admin) ─────────────────────────

  int get _pendingKycCount =>
      _kycList.where((item) => item.status == 'pending').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AnimatedBuilder(
        animation: widget.consoleState,
        builder: (context, _) {
          final activeSellers = widget.consoleState.sellers
              .where((seller) => seller['status'] == 'active')
              .length;
          final suspendedSellers =
              widget.consoleState.sellers.length - activeSellers;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              const Text(
                'ศูนย์ควบคุมหลังบ้าน (Admin)',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              _serverBanner(),
              _buildOverview(activeSellers, suspendedSellers),
              const SizedBox(height: 20),
              _buildSectionTabs(),
              const SizedBox(height: 18),
              ..._selectedSection == 0
                  ? _sellerList()
                  : _selectedSection == 1
                  ? _dormRequestList()
                  : _selectedSection == 2
                  ? _kycRequestList()
                  : _reviewList(),
            ],
          );
        },
      ),
    );
  }

  /// บอกว่าตอนนี้เป็นข้อมูลจริงจาก server หรือข้อมูลตัวอย่าง
  Widget _serverBanner() {
    final state = widget.consoleState;
    if (state.loadingServer) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: LinearProgressIndicator(),
      );
    }
    final String text;
    final IconData icon;
    if (state.serverError != null) {
      text = state.serverError!;
      icon = Icons.cloud_off_outlined;
    } else if (state.serverMode) {
      return const SizedBox.shrink();
    } else {
      text = 'ข้อมูลตัวอย่าง — เข้าสู่ระบบด้วยบัญชีแอดมิน (admin@test.com) '
          'เพื่ออนุมัติหอและระงับบัญชีจริง';
      icon = Icons.info_outline;
    }
    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: Icon(icon),
        title: Text(text, style: const TextStyle(fontSize: 13)),
        trailing: state.serverError != null
            ? IconButton(
                tooltip: 'ลองใหม่',
                icon: const Icon(Icons.refresh),
                onPressed: state.loadFromServer,
              )
            : null,
      ),
    );
  }

  Widget _buildOverview(int activeSellers, int suspendedSellers) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.hero,
            borderRadius: BorderRadius.circular(28),
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
                  Icons.visibility_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ยอดเข้าชมรวม',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.consoleState.totalViews} ครั้ง',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusPill(
                'ภาพรวมระบบ',
                color: AppColors.ink,
                background: Colors.white,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'ผู้ขายใช้งาน',
                '$activeSellers',
                'ราย',
                Icons.store,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                'บัญชีถูกระงับ',
                '$suspendedSellers',
                'ราย',
                Icons.block,
                AppColors.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                'หอรอตรวจเอกสาร',
                '${widget.consoleState.pendingDormCount}',
                'หอ',
                Icons.apartment,
                AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          _sectionChip('ผู้ขาย', 0, Icons.people_alt_outlined),
          _sectionChip(
            'คำขอลงหอ',
            1,
            Icons.fact_check_outlined,
            badge: widget.consoleState.pendingDormCount,
          ),
          _sectionChip(
            'ตรวจ KYC',
            2,
            Icons.verified_user_outlined,
            badge: _pendingKycCount,
          ),
          _sectionChip(
            'รีวิว',
            3,
            Icons.rate_review_outlined,
            badge: widget.consoleState.hiddenReviewCount,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );

  Widget _emptyState(IconData icon, String text) => AppCard(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, size: 44, color: AppColors.muted),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );

  Widget _miniStat(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.muted),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  List<Widget> _sellerList() => [
    _sectionTitle('บัญชีเจ้าของหอ'),
    ...widget.consoleState.sellers.map((seller) {
      final suspended = seller['status'] == 'suspended';
      final verified = seller['kyc'] == 'verified';
      final views =
          widget.consoleState.dormViews[seller['dormId']] ?? seller['views'];
      return AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _showSellerDetails(seller),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: suspended
                            ? AppColors.dangerSoft
                            : AppColors.field,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        suspended ? Icons.person_off_outlined : Icons.store,
                        color: suspended ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seller['name'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            seller['dorm'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      suspended ? Icons.block : Icons.chevron_right,
                      color: suspended ? AppColors.danger : AppColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                      suspended ? 'ถูกระงับ' : 'ใช้งานอยู่',
                      color: suspended ? AppColors.danger : AppColors.success,
                      background: suspended
                          ? AppColors.dangerSoft
                          : AppColors.successSoft,
                    ),
                    StatusPill(
                      verified ? 'KYC ยืนยันแล้ว' : 'KYC รอตรวจ',
                      icon: verified
                          ? Icons.verified_rounded
                          : Icons.hourglass_top_rounded,
                      color: verified ? AppColors.info : AppColors.warning,
                      background: verified
                          ? AppColors.infoSoft
                          : AppColors.warningSoft,
                    ),
                    _miniStat(Icons.visibility_outlined, '$views วิว'),
                    _miniStat(
                      Icons.flag_outlined,
                      'รายงาน ${seller['reports']}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }),
  ];

  List<Widget> _dormRequestList() {
    final requests = widget.consoleState.dormRequests;
    if (requests.isEmpty) {
      return [
        _sectionTitle('คำขอลงประกาศหอพัก'),
        _emptyState(Icons.inbox_outlined, 'ยังไม่มีคำขอลงประกาศหอ'),
      ];
    }
    return [
      _sectionTitle('คำขอลงประกาศหอพัก'),
      ...requests.map((request) {
        final status = request['status'];
        final pending = status == 'pending';
        final approved = status == 'approved';
        final color = pending
            ? AppColors.warning
            : approved
            ? AppColors.success
            : AppColors.danger;
        final background = pending
            ? AppColors.warningSoft
            : approved
            ? AppColors.successSoft
            : AppColors.dangerSoft;
        final docs = List.from(request['documents'] ?? const []);
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: pending ? () => _showDormRequest(request) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      pending
                          ? Icons.pending_actions
                          : approved
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${request['sellerName']} • ${request['location']}',
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
                            StatusPill(
                              pending
                                  ? 'รอตรวจสอบ'
                                  : approved
                                  ? 'อนุมัติแล้ว'
                                  : 'ไม่อนุมัติ',
                              color: color,
                              background: background,
                            ),
                            const SizedBox(width: 8),
                            _miniStat(
                              Icons.description_outlined,
                              '${docs.length} เอกสาร',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (pending)
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          ),
        );
      }),
    ];
  }

  List<Widget> _kycRequestList() => [
    _sectionTitle('คำขอ KYC รอตรวจ $_pendingKycCount รายการ'),
    ..._kycList.map((item) {
      final pending = item.status == 'pending';
      final approved = item.status == 'approved';
      final color = pending
          ? AppColors.warning
          : approved
          ? AppColors.success
          : AppColors.danger;
      final background = pending
          ? AppColors.warningSoft
          : approved
          ? AppColors.successSoft
          : AppColors.dangerSoft;
      return AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminKYCDetailView(kycItem: item),
              ),
            );
            if (result != null) setState(() => item.status = result.toString());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.verified_user_outlined, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'หอพัก: ${item.dormName}',
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
                          StatusPill(
                            pending
                                ? 'รอตรวจ'
                                : approved
                                ? 'อนุมัติแล้ว'
                                : 'ปฏิเสธ',
                            color: color,
                            background: background,
                          ),
                          const SizedBox(width: 8),
                          _miniStat(
                            Icons.event_outlined,
                            'ยื่น ${item.submissionDate}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      );
    }),
  ];

  // ───────────────────────── จัดการรีวิว ─────────────────────────

  Future<void> _confirmDeleteReview(Map<String, dynamic> review) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรีวิวนี้ถาวร'),
        content: Text(
          'ลบรีวิวของ ${review['author']} ใน ${review['dormName']} หรือไม่? การลบไม่สามารถกู้คืนได้ (หากไม่แน่ใจ ให้เลือก "ซ่อน" แทน)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบรีวิว'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.consoleState.deleteReview(review['id'].toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบรีวิวแล้ว')),
      );
    }
  }

  List<Widget> _reviewList() {
    final reviews = widget.consoleState.reviews;
    if (reviews.isEmpty) {
      return [
        _sectionTitle('จัดการรีวิว'),
        _emptyState(Icons.rate_review_outlined, 'ยังไม่มีรีวิวในระบบ'),
      ];
    }
    return [
      _sectionTitle('จัดการรีวิว (${reviews.length})'),
      ...reviews.map((review) {
        final hidden = review['status'] == 'hidden';
        final rating = (review['rating'] as num).toInt();
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.field,
                      child: const Icon(
                        Icons.person_outline,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review['author'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${review['dormName']} • ${review['date']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      hidden ? 'ซ่อนอยู่' : 'แสดงอยู่',
                      color: hidden ? AppColors.warning : AppColors.success,
                      background: hidden
                          ? AppColors.warningSoft
                          : AppColors.successSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: AppColors.star,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  review['comment'].toString(),
                  style: TextStyle(
                    height: 1.45,
                    fontSize: 13.5,
                    color: hidden ? AppColors.muted : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.consoleState.setReviewHidden(
                          review['id'].toString(),
                          !hidden,
                        ),
                        icon: Icon(
                          hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        label: Text(hidden ? 'แสดงรีวิว' : 'ซ่อนรีวิว'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDeleteReview(review),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('ลบ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  Widget _sectionChip(String label, int index, IconData icon, {int badge = 0}) {
    final selected = _selectedSection == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedSection = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected ? AppShadows.dark : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: AppShadows.soft,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
  );

  Widget _detail(String title, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        SizedBox(
          width: 112,
          child: Text(
            title,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _metric(String title, String value, IconData icon) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.ink),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    ),
  );
}
