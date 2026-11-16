import '../../lib/models/admin_console_state.dart';

List<String> dormIds(List<Map<String, dynamic>> dorms) =>
    dorms.map((dorm) => dorm['id'].toString()).toList();

void submitOwnerDorm(
  AdminConsoleState state, {
  required String id,
  required String name,
  int min = 5000,
  int max = 8000,
  List<String> amenities = const ['แอร์'],
}) {
  state.submitDormRequest(
    sellerId: 'seller_new',
    sellerName: 'เจ้าของใหม่',
    dormId: id,
    dormName: name,
    phone: '0800000000',
    location: 'ที่ตั้งของ $name',
    latitude: null,
    longitude: null,
    description: 'รายละเอียด',
    priceMin: min,
    priceMax: max,
    amenities: amenities,
    imageUrl: '',
    documents: const <Map<String, String>>[],
  );
}
