/// Represents a topic (keyword) associated with books in the library.
class Topic {
  /// The unique identifier of the topic.
  final int id;

  /// The name of the topic.
  final String name;

  const Topic({
    this.id = 0,
    required this.name,
  });

  /// Creates a Topic instance from a map (e.g., a database row).
  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  /// Creates a Topic instance from JSON.
  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String,
    );
  }

  /// Converts the Topic to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  Topic copyWith({
    int? id,
    String? name,
  }) {
    return Topic(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  String toString() => 'Topic(id: $id, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Topic && other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
