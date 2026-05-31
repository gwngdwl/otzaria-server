/// Represents a generation entity in the database.
class Generation {
  final int id;
  final String name;
  final int? startYear;
  final int? endYear;
  final int? parentGenerationId;

  const Generation({
    this.id = 0,
    required this.name,
    this.startYear,
    this.endYear,
    this.parentGenerationId,
  });

  factory Generation.fromJson(Map<String, dynamic> json) {
    return Generation(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String,
      startYear: json['startYear'] as int?,
      endYear: json['endYear'] as int?,
      parentGenerationId: json['parentGenerationId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startYear': startYear,
      'endYear': endYear,
      'parentGenerationId': parentGenerationId,
    };
  }
}
