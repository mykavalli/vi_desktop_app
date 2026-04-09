import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';

class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._();
  GoogleDriveService._();

  static final _scopes = [drive.DriveApi.driveFileScope];
  static const _folderName = 'Vi Desktop App Backups';

  AuthClient? _client;

  bool get isAuthenticated => _client != null;
  // Giữ tương thích với code cũ (có thể là IsAuthenticated viết hoa)
  bool get IsAuthenticated => _client != null;

  Future<bool> authenticate() async {
    try {
      final user = await DatabaseHelper.instance.getUser();
      final clientId = user?.googleClientId;
      final clientSecret = user?.googleClientSecret;

      if (clientId == null || clientId.trim().isEmpty) {
        throw Exception('Vui lòng cấu hình Google Client ID trong phần cài đặt tài khoản.');
      }

      final id = ClientId(clientId, clientSecret ?? '');

      _client = await clientViaUserConsent(id, _scopes, (url) {
        launchUrl(Uri.parse(url));
      });

      return true;
    } catch (e) {
      print('Google Drive Auth Error: $e');
      rethrow;
    }
  }

  void signOut() {
    _client?.close();
    _client = null;
  }

  // ==================== UPLOAD ====================

  Future<double?> uploadBackup(File dbFile) async {
    if (_client == null) return null;

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
    if (_client == null) throw Exception('Chưa xác thực Google Drive.');

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
    if (_client == null) throw Exception('Chưa xác thực Google Drive.');

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
