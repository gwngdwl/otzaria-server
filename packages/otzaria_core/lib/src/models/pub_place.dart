/// Represents a publication place.
class PubPlace {
  /// The unique identifier of the publication place.
  final int id;

  /// The name of the publication place.
  final String name;

  const PubPlace({
    this.id = 0,
    required this.name,
  });

  /// Creates a PubPlace instance from a map (e.g., a database row).
  factory PubPlace.fromMap(Map<String, dynamic> map) {
    return PubPlace(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  /// Creates a PubPlace instance from JSON.
  factory PubPlace.fromJson(Map<String, dynamic> json) {
    return PubPlace(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String,
    );
  }

  /// Converts the PubPlace to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  PubPlace copyWith({
    int? id,
    String? name,
  }) {
    return PubPlace(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  String toString() => 'PubPlace(id: $id, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PubPlace && other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
