import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';

class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._();
  GoogleDriveService._();

  static final _scopes = [
    drive.DriveApi.driveFileScope,
    'https://www.googleapis.com/auth/userinfo.email',
  ];
  // Client ID mặc định của ứng dụng (dành cho người dùng thông thường không cần tự tạo Project GCP)
  static const String defaultClientId =
      '807663248384-j0l9j4u9k5c84f4p5f3l71n9k0c1a2b3.apps.googleusercontent.com';
  static const String defaultClientSecret = '';
  static const _folderName = 'Vi Desktop App Backups';

  AutoRefreshingAuthClient? _client;
  String? _currentUserEmail;

  bool get isAuthenticated => _client != null;
  bool get IsAuthenticated => _client != null;
  String? get currentUserEmail => _currentUserEmail;

  /// Map AccessCredentials to JSON Map
  Map<String, dynamic> _credentialsToJson(AccessCredentials credentials) {
    return {
      'type': credentials.accessToken.type,
      'data': credentials.accessToken.data,
      'expiry': credentials.accessToken.expiry.toUtc().toIso8601String(),
      'refreshToken': credentials.refreshToken,
      'scopes': credentials.scopes,
      'idToken': credentials.idToken,
    };
  }

  /// Rebuild AccessCredentials from JSON Map
  AccessCredentials _credentialsFromJson(Map<String, dynamic> json) {
    return AccessCredentials(
      AccessToken(
        json['type'] as String? ?? 'Bearer',
        json['data'] as String,
        DateTime.parse(json['expiry'] as String).toUtc(),
      ),
      json['refreshToken'] as String?,
      (json['scopes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? _scopes,
      idToken: json['idToken'] as String?,
    );
  }

  /// Tự động khôi phục phiên đăng nhập đã lưu trong database
  Future<bool> restoreSession() async {
    if (_client != null) return true;
    try {
      final user = await DatabaseHelper.instance.getUser();
      final userClientId = user?.googleClientId?.trim();
      final userClientSecret = user?.googleClientSecret?.trim();
      final authJson = user?.googleAuthJson;
      final userEmail = user?.googleUserEmail;

      if (authJson == null || authJson.trim().isEmpty) {
        return false;
      }

      final credsMap = jsonDecode(authJson) as Map<String, dynamic>;
      final credentials = _credentialsFromJson(credsMap);

      // Nếu không có refreshToken và token đã hết hạn thì không thể khôi phục
      if (credentials.refreshToken == null && credentials.accessToken.expiry.isBefore(DateTime.now().toUtc())) {
        return false;
      }

      final activeClientId = (userClientId != null && userClientId.isNotEmpty)
          ? userClientId
          : defaultClientId;
      final activeClientSecret = (userClientSecret != null && userClientSecret.isNotEmpty)
          ? userClientSecret
          : defaultClientSecret;

      final id = ClientId(activeClientId, activeClientSecret);
      final baseClient = http.Client();
      final client = autoRefreshingClient(id, credentials, baseClient);

      _client = client;
      _currentUserEmail = userEmail;

      // Lắng nghe sự kiện tự động refresh token để cập nhật lại DB
      client.credentialUpdates.listen((newCreds) async {
        final updatedJson = jsonEncode(_credentialsToJson(newCreds));
        await DatabaseHelper.instance.saveGoogleAuth(updatedJson, _currentUserEmail);
      });

      return true;
    } catch (e) {
      print('Google Drive Session Restore Error: $e');
      _client = null;
      return false;
    }
  }

  /// Thực hiện đăng nhập Google qua Consent Flow trên trình duyệt
  Future<bool> authenticate() async {
    try {
      final user = await DatabaseHelper.instance.getUser();
      final userClientId = user?.googleClientId?.trim();
      final userClientSecret = user?.googleClientSecret?.trim();

      final activeClientId = (userClientId != null && userClientId.isNotEmpty)
          ? userClientId
          : defaultClientId;
      final activeClientSecret = (userClientSecret != null && userClientSecret.isNotEmpty)
          ? userClientSecret
          : defaultClientSecret;

      final id = ClientId(activeClientId, activeClientSecret);

      final client = await clientViaUserConsent(id, _scopes, (url) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      });

      _client = client;

      // Lấy thông tin email tài khoản Google
      String? email;
      try {
        final response = await client.get(Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'));
        if (response.statusCode == 200) {
          final info = jsonDecode(response.body) as Map<String, dynamic>;
          email = info['email'] as String?;
        }
      } catch (e) {
        print('Không thể lấy Google user info: $e');
      }

      _currentUserEmail = email;

      // Lưu credentials vào database để ghi nhớ đăng nhập
      final authJson = jsonEncode(_credentialsToJson(client.credentials));
      await DatabaseHelper.instance.saveGoogleAuth(authJson, email);

      // Lắng nghe sự kiện token refresh sau này
      client.credentialUpdates.listen((newCreds) async {
        final updatedJson = jsonEncode(_credentialsToJson(newCreds));
        await DatabaseHelper.instance.saveGoogleAuth(updatedJson, _currentUserEmail);
      });

      return true;
    } catch (e) {
      print('Google Drive Auth Error: $e');
      rethrow;
    }
  }

  /// Đăng xuất tài khoản Google và xóa thông tin lưu trữ
  Future<void> signOut() async {
    _client?.close();
    _client = null;
    _currentUserEmail = null;
    await DatabaseHelper.instance.clearGoogleAuth();
  }

  // ==================== UPLOAD ====================

  Future<double?> uploadBackup(File dbFile) async {
    if (_client == null) {
      final restored = await restoreSession();
      if (!restored || _client == null) return null;
    }

    final driveApi = drive.DriveApi(_client!);

    String? folderId = await _getFolderId(driveApi, _folderName);
    folderId ??= await _createFolder(driveApi, _folderName);
    if (folderId == null) return null;

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')[0];
    final driveFile = drive.File()
      ..name = 'backup_$timestamp.db'
      ..parents = [folderId];

    final media = drive.Media(dbFile.openRead(), dbFile.lengthSync());
    await driveApi.files.create(driveFile, uploadMedia: media);
    return 1.0;
  }

  // ==================== LIST BACKUPS ====================

  /// Liệt kê tất cả file backup trên Drive, sắp xếp theo thời gian giảm dần
  Future<List<drive.File>> listBackups() async {
    if (_client == null) {
      final restored = await restoreSession();
      if (!restored || _client == null) {
        throw Exception('Chưa xác thực Google Drive.');
      }
    }

    final driveApi = drive.DriveApi(_client!);
    final folderId = await _getFolderId(driveApi, _folderName);
    if (folderId == null) return [];

    final result = await driveApi.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      $fields: 'files(id,name,size,createdTime)',
      spaces: 'drive',
    );

    return result.files ?? [];
  }

  // ==================== DOWNLOAD / RESTORE ====================

  /// Download một file backup về thư mục temp, trả về File path để restore
  Future<File> downloadBackup(String fileId, String fileName) async {
    if (_client == null) {
      final restored = await restoreSession();
      if (!restored || _client == null) {
        throw Exception('Chưa xác thực Google Drive.');
      }
    }

    final driveApi = drive.DriveApi(_client!);
    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');

    final sink = tempFile.openWrite();
    await media.stream.pipe(sink);
    await sink.close();

    return tempFile;
  }

  // ==================== HELPERS ====================

  Future<String?> _getFolderId(drive.DriveApi api, String folderName) async {
    final list = await api.files.list(
      q: "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (list.files == null || list.files!.isEmpty) return null;
    return list.files!.first.id;
  }

  Future<String?> _createFolder(drive.DriveApi api, String folderName) async {
    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final result = await api.files.create(folder);
    return result.id;
  }
}
