class User {
  final int? id;
  final String passwordHash;
  final DateTime createdAt;

  User({this.id, required this.passwordHash, required this.createdAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'password_hash': passwordHash,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      passwordHash: map['password_hash'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
