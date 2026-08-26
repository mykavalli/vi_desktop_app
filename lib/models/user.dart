class User {
  final int? id;
  final String passwordHash;
  final String? googleClientId;
  final String? googleClientSecret;
  final String? googleAuthJson;
  final String? googleUserEmail;
  final DateTime createdAt;

  User({
    this.id, 
    required this.passwordHash, 
    this.googleClientId,
    this.googleClientSecret,
    this.googleAuthJson,
    this.googleUserEmail,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'password_hash': passwordHash,
      'google_client_id': googleClientId,
      'google_client_secret': googleClientSecret,
      'google_auth_json': googleAuthJson,
      'google_user_email': googleUserEmail,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      passwordHash: map['password_hash'],
      googleClientId: map['google_client_id'],
      googleClientSecret: map['google_client_secret'],
      googleAuthJson: map['google_auth_json'],
      googleUserEmail: map['google_user_email'],
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
