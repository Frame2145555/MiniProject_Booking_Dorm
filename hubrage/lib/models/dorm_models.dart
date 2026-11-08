class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String role; // 'user' or 'admin'
  final String userType;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.userType,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['user_id'],
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'user',
      userType: json['user_type'] ?? 'student',
    );
  }
}

class RoomModel {
  final int id;
  final String buildingId;
  final String number;
  final String type;
  final double price;
  String status; // 'available', 'reserved', 'occupied'
  final int floor;

  RoomModel({
    required this.id,
    required this.buildingId,
    required this.number,
    required this.type,
    required this.price,
    required this.status,
    required this.floor,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['room_id'] ?? 0,
      buildingId: json['building_code'] ?? 'A',
      number: json['room_number'] ?? '',
      type: json['type_name'] ?? 'Single Studio',
      price: double.parse((json['price_per_month'] ?? 600).toString()),
      status: (json['occupied_count'] ?? 0) > 0 ? 'occupied' : 'available',
      floor: json['floor'] ?? 1,
    );
  }
}

class BookingModel {
  final String id;
  final String roomNumber;
  final String buildingName;
  final String status;
  final double totalMonthly;

  BookingModel({
    required this.id,
    required this.roomNumber,
    required this.buildingName,
    required this.status,
    required this.totalMonthly,
  });
}