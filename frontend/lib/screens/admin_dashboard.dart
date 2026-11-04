import 'package:flutter/material.dart';
import '../models/building.dart';
import '../models/room.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<BuildingModel> _buildings = [
    BuildingModel(id: '1', name: 'Building A - Sunflower', totalFloors: 5, genderType: 'Mixed', description: 'Near main library'),
    BuildingModel(id: '2', name: 'Building B - Orchid', totalFloors: 4, genderType: 'Female', description: 'Female only zone'),
    BuildingModel(id: '3', name: 'Building C - Rose', totalFloors: 6, genderType: 'Male', description: 'Male zone'),
  ];

  final List<RoomModel> _rooms = [
    RoomModel(id: '1', buildingId: '1', buildingName: 'Building A', roomNumber: '101', floor: 1, roomType: 'Standard Single', price: 4500, status: 'available', amenities: ['Wi-Fi', 'AC']),
    RoomModel(id: '2', buildingId: '1', buildingName: 'Building A', roomNumber: '201', floor: 2, roomType: 'Deluxe Double', price: 6500, status: 'reserved', amenities: ['Wi-Fi', 'AC', 'Water Heater']),
    RoomModel(id: '3', buildingId: '2', buildingName: 'Building B', roomNumber: '102', floor: 1, roomType: 'Standard Single', price: 4800, status: 'occupied', amenities: ['Wi-Fi']),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _showAddBuildingDialog() {
    final nameCtrl = TextEditingController();
    final floorCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มตึกใหม่ (Add Building)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อตึก')),
            TextField(controller: floorCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'จำนวนชั้น')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && floorCtrl.text.isNotEmpty) {
                setState(() {
                  _buildings.add(BuildingModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text,
                    totalFloors: int.parse(floorCtrl.text),
                    genderType: 'Mixed',
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DormSpace Admin Dashboard (Sprint 2)'),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.apartment), text: 'ตึก (Buildings)'),
            Tab(icon: Icon(Icons.meeting_room), text: 'ห้อง (Rooms)'),
            Tab(icon: Icon(Icons.more_horiz), text: 'Addons/Semesters'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: BUILDINGS
          ListView.builder(
            itemCount: _buildings.length,
            itemBuilder: (context, idx) {
              final b = _buildings[idx];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF4F46E5), child: Icon(Icons.domain, color: Colors.white)),
                  title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('จำนวน: ${b.totalFloors} ชั้น | ประเภท: ${b.genderType}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _buildings.removeAt(idx);
                      });
                    },
                  ),
                ),
              );
            },
          ),
          // TAB 2: ROOMS
          ListView.builder(
            itemCount: _rooms.length,
            itemBuilder: (context, idx) {
              final r = _rooms[idx];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: r.status == 'available' ? Colors.green : (r.status == 'reserved' ? Colors.orange : Colors.grey),
                    child: Text(r.roomNumber, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  title: Text('ห้อง ${r.roomNumber} (${r.buildingName})'),
                  subtitle: Text('ประเภท: ${r.roomType} | ฿${r.price}/เดือน'),
                  trailing: Chip(
                    label: Text(r.status),
                    backgroundColor: r.status == 'available' ? Colors.green.shade100 : Colors.amber.shade100,
                  ),
                ),
              );
            },
          ),
          // TAB 3: ADDONS
          const Center(
            child: Text('ส่วนจัดการ Add-ons, สิ่งอำนวยความสะดวก และ เทอมการศึกษา'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBuildingDialog,
        backgroundColor: const Color(0xFF4F46E5),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
