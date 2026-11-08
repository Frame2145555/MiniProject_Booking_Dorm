class DormModel {
  final String id;
  final String title;
  final String location;
  final String priceRange;
  final double rating;
  final String imageUrl;
  final List<String> amenities;
  final String phone;

  DormModel({
    required this.id,
    required this.title,
    required this.location,
    required this.priceRange,
    required this.rating,
    required this.imageUrl,
    required this.amenities,
    required this.phone,
  });
}

class RoomDetailModel {
  final String roomNumber;
  final String roomType;
  final double price;
  final String status; // 'ว่าง', 'มีผู้เช่า', 'ปรับปรุง'

  RoomDetailModel({
    required this.roomNumber,
    required this.roomType,
    required this.price,
    required this.status,
  });
}
