import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';

class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._();
  GoogleDriveService._();

  static final _scopes = [drive.DriveApi.driveFileScope];

  AuthClient? _client;

  bool get IsAuthenticated => _client != null;

  Future<bool> authenticate() async {
    try {
      final user = await DatabaseHelper.instance.getUser();
      final clientId = user?.googleClientId;
      final clientSecret = user?.googleClientSecret;

      if (clientId == null || clientId.trim().isEmpty) {
        throw Exception("Vui lòng cấu hình Google Client ID trong phần cài đặt tài khoản.");
      }

      final id = ClientId(clientId, clientSecret ?? '');
      
      _client = await clientViaUserConsent(id, _scopes, (url) {
        launchUrl(Uri.parse(url));
      });
      
      return true;
    } catch (e) {
      print("Google Drive Auth Error: $e");
      return false;
    }
  }

  Future<double?> uploadBackup(File dbFile) async {
    if (_client == null) return null;

    final driveApi = drive.DriveApi(_client!);
    
    // 1. Find or create 'Vi Desktop App Backups' folder
    String? folderId = await _getFolderId(driveApi, "Vi Desktop App Backups");
    if (folderId == null) {
      folderId = await _createFolder(driveApi, "Vi Desktop App Backups");
    }

    if (folderId == null) return null;

    // 2. Upload file
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final driveFile = drive.File();
    driveFile.name = "backup_$timestamp.db";
    driveFile.parents = [folderId];

    final media = drive.Media(dbFile.openRead(), dbFile.lengthSync());
    
    await driveApi.files.create(driveFile, uploadMedia: media);
    return 1.0; // 100% complete
  }

  Future<String?> _getFolderId(drive.DriveApi api, String folderName) async {
    final list = await api.files.list(
      q: "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
    );
    if (list.files == null || list.files!.isEmpty) return null;
    return list.files!.first.id;
  }

  Future<String?> _createFolder(drive.DriveApi api, String folderName) async {
    final folder = drive.File();
    folder.name = folderName;
    folder.mimeType = "application/vnd.google-apps.folder";
    final result = await api.files.create(folder);
    return result.id;
  }
}
