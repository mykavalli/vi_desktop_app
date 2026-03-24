import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../database/database_helper.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  final DatabaseHelper _db = DatabaseHelper.instance;

  AuthService._init();

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> authenticate(String password) async {
    final user = await _db.getUser();
    if (user == null) {
      return password == 'admin';
    }
    final inputHash = hashPassword(password);
    return inputHash == user.passwordHash;
  }

  Future<void> initializeDefaultPassword() async {
    final user = await _db.getUser();
    if (user == null) {
      final defaultHash = hashPassword('admin');
      await _db.updateUserPassword(defaultHash);
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final isAuthenticated = await authenticate(oldPassword);
    if (!isAuthenticated) return false;

    final newHash = hashPassword(newPassword);
    await _db.updateUserPassword(newHash);
    return true;
  }

  Future<bool> isFirstTime() async {
    final user = await _db.getUser();
    return user == null;
  }
}
