import 'package:flutter/material.dart';

import '../models/admin_console_state.dart';
import '../models/kyc_request_model.dart';
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
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.store, color: Colors.deepOrange),
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
                            color: suspended ? Colors.red : Colors.green,
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
                    color: suspended ? Colors.green : Colors.red,
                  ),
                  label: Text(
                    suspended ? 'คืนสถานะบัญชี' : 'ระงับบัญชีผู้ขาย',
                    style: TextStyle(
                      color: suspended ? Colors.green : Colors.red,
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
                  style: TextStyle(color: Colors.red),
                ),
              ...documents.map(
                (document) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: Colors.deepOrange,
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
            child: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ศูนย์ควบคุมหลังบ้าน (Admin)'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: widget.consoleState,
        builder: (context, _) {
          final activeSellers = widget.consoleState.sellers
              .where((seller) => seller['status'] == 'active')
              .length;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'ผู้ขายใช้งาน',
                        '$activeSellers ราย',
                        Icons.store,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        'บัญชีถูกระงับ',
                        '${widget.consoleState.sellers.length - activeSellers} ราย',
                        Icons.block,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'หอรอตรวจเอกสาร',
                        '${widget.consoleState.pendingDormCount} หอ',
                        Icons.apartment,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        'ยอดเข้าชมรวม',
                        '${widget.consoleState.totalViews} ครั้ง',
                        Icons.visibility,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _sectionChip('ผู้ขาย', 0, Icons.people_alt_outlined),
                      const SizedBox(width: 8),
                      _sectionChip(
                        'คำขอลงประกาศหอ',
                        1,
                        Icons.fact_check_outlined,
                      ),
                      const SizedBox(width: 8),
                      _sectionChip('ตรวจ KYC', 2, Icons.verified_user_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _selectedSection == 0
                      ? _sellerList()
                      : _selectedSection == 1
                      ? _dormRequestList()
                      : _kycRequestList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sellerList() => ListView(
    children: [
      const Text(
        'บัญชีเจ้าของหอ',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      ...widget.consoleState.sellers.map((seller) {
        final suspended = seller['status'] == 'suspended';
        final views =
            widget.consoleState.dormViews[seller['dormId']] ?? seller['views'];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: suspended
                  ? Colors.red.shade100
                  : Colors.orange.shade100,
              child: Icon(
                suspended ? Icons.person_off_outlined : Icons.store,
                color: suspended ? Colors.red : Colors.deepOrange,
              ),
            ),
            title: Text(
              seller['name'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${seller['dorm']}\nKYC: ${seller['kyc'] == 'verified' ? 'ยืนยันแล้ว' : 'รอตรวจ'} • $views วิว • รายงาน ${seller['reports']}',
            ),
            isThreeLine: true,
            trailing: Icon(
              suspended ? Icons.block : Icons.chevron_right,
              color: suspended ? Colors.red : Colors.grey,
            ),
            onTap: () => _showSellerDetails(seller),
          ),
        );
      }),
    ],
  );

  Widget _dormRequestList() {
    final requests = widget.consoleState.dormRequests;
    if (requests.isEmpty)
      return const Center(child: Text('ยังไม่มีคำขอลงประกาศหอ'));
    return ListView(
      children: [
        const Text(
          'คำขอลงประกาศหอพัก',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...requests.map((request) {
          final status = request['status'];
          final pending = status == 'pending';
          final approved = status == 'approved';
          final color = pending
              ? Colors.orange
              : approved
              ? Colors.green
              : Colors.red;
          final docs = List.from(request['documents'] ?? const []);
          return Card(
            child: ListTile(
              leading: Icon(
                pending
                    ? Icons.pending_actions
                    : approved
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: color,
              ),
              title: Text(request['dormName'].toString()),
              subtitle: Text(
                '${request['sellerName']} • ${request['location']}\n${docs.length} เอกสาร • ${pending
                    ? 'รอตรวจสอบ'
                    : approved
                    ? 'อนุมัติแล้ว'
                    : 'ไม่อนุมัติ'}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: pending ? () => _showDormRequest(request) : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _kycRequestList() => ListView(
    children: [
      Text(
        'คำขอ KYC รอตรวจ ${_kycList.where((item) => item.status == 'pending').length} รายการ',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      ..._kycList.map(
        (item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFF3E0),
              child: Icon(
                Icons.verified_user_outlined,
                color: Colors.deepOrange,
              ),
            ),
            title: Text(
              item.sellerName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'หอพัก: ${item.dormName}\nวันที่ยื่น: ${item.submissionDate} • สถานะ: ${item.status}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminKYCDetailView(kycItem: item),
                ),
              );
              if (result != null)
                setState(() => item.status = result.toString());
            },
          ),
        ),
      ),
    ],
  );

  Widget _sectionChip(String label, int index, IconData icon) => ChoiceChip(
    avatar: Icon(
      icon,
      size: 17,
      color: _selectedSection == index ? Colors.white : Colors.redAccent,
    ),
    label: Text(label),
    selected: _selectedSection == index,
    selectedColor: Colors.redAccent,
    labelStyle: TextStyle(
      color: _selectedSection == index ? Colors.white : Colors.black87,
    ),
    onSelected: (_) => setState(() => _selectedSection = index),
  );

  Widget _summaryCard(String title, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11)),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _detail(String title, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(
          width: 112,
          child: Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
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

  Widget _metric(String title, String value, IconData icon) => Column(
    children: [
      Icon(icon, color: Colors.deepOrange),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    ],
  );
}
