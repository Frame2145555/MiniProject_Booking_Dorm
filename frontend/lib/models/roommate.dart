/// Model: รูมเมทของการจอง (ตรงกับ API /api/dashboard/bookings/:id/roommates)
class Roommate {
  final String fullName;
  final String faculty;
  final int? matchPercent; // null = ยังไม่ได้ตอบแบบสอบถาม
  final bool sameSleepHabit;

  const Roommate({
    required this.fullName,
    required this.faculty,
    required this.matchPercent,
    required this.sameSleepHabit,
  });

  /// ตัวอักษรย่อไว้โชว์ในวงกลม เช่น "Jordan Lee" -> "JL"
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
