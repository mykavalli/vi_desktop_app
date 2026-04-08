class User {
  final int? id;
  final String passwordHash;
  final String? googleClientId;
  final String? googleClientSecret;
  final DateTime createdAt;

  User({
    this.id, 
    required this.passwordHash, 
    this.googleClientId,
    this.googleClientSecret,
    required this.createdAt
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'password_hash': passwordHash,
      'google_client_id': googleClientId,
      'google_client_secret': googleClientSecret,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      passwordHash: map['password_hash'],
      googleClientId: map['google_client_id'],
      googleClientSecret: map['google_client_secret'],
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
