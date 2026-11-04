class RoomModel {
  final String id;
  final String buildingId;
  final String buildingName;
  final String roomNumber;
  final int floor;
  final String roomType;
  double price;
  String status; // 'available', 'reserved', 'occupied', 'maintenance'
  final List<String> amenities;

  RoomModel({
    required this.id,
    required this.buildingId,
    required this.buildingName,
    required this.roomNumber,
    required this.floor,
    required this.roomType,
    required this.price,
    required this.status,
    required this.amenities,
  });
}
