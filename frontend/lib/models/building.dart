class BuildingModel {
  final String id;
  String name;
  int totalFloors;
  String genderType;
  String? description;

  BuildingModel({
    required this.id,
    required this.name,
    required this.totalFloors,
    required this.genderType,
    this.description,
  });
}
