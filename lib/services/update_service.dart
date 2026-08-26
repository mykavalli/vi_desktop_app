import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String changelog;
  final String downloadUrl;
  final bool mandatory;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.changelog,
    required this.downloadUrl,
    this.mandatory = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      buildNumber: json['build_number'] as int? ?? 1,
      releaseDate: json['release_date'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}

class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  // Thông tin phiên bản hiện tại của App
  static const String currentVersion = '1.0.0';
  static const int currentBuildNumber = 1;

  // Endpoint mặc định kiểm tra update từ nhánh Git (raw GitHub)
  static const String defaultUpdateUrl =
      'https://raw.githubusercontent.com/mykavalli/vi_desktop_app/updates/version.json';

  /// So sánh phiên bản remote với phiên bản hiện tại
  bool _isNewer(String remoteVer, int remoteBuild) {
    if (remoteBuild > currentBuildNumber) return true;

    List<int> parse(String v) {
      return v
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
    }

    final r = parse(remoteVer);
    final c = parse(currentVersion);

    for (int i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }

    return false;
  }

  /// Kiểm tra có bản cập nhật mới trên Git hay không
  Future<UpdateInfo?> checkForUpdates({String? customUrl}) async {
    final url = customUrl ?? defaultUpdateUrl;
    final uri = Uri.parse(url);

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(data);

      if (_isNewer(info.version, info.buildNumber)) {
        return info;
      }
      return null; // Đang ở bản mới nhất
    } else if (response.statusCode == 404) {
      throw Exception(
        'Không thể tải version.json (Mã lỗi 404: Repository GitHub đang ở chế độ Private). Vui lòng chuyển Repo sang Public để tải bản cập nhật.',
      );
    } else {
      throw Exception('Máy chủ cập nhật phản hồi mã lỗi HTTP ${response.statusCode}');
    }
  }

  /// Tải file cập nhật (zip hoặc exe) và kích hoạt quy trình cập nhật
  Future<void> downloadAndApplyUpdate({
    required UpdateInfo updateInfo,
    required void Function(double progress, String message) onProgress,
  }) async {
    final downloadUri = Uri.parse(updateInfo.downloadUrl);
    final isZip = downloadUri.path.toLowerCase().endsWith('.zip');
    final isExe = downloadUri.path.toLowerCase().endsWith('.exe');

    final client = http.Client();
    final request = http.Request('GET', downloadUri);
    final response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Không thể tải bản cập nhật (HTTP ${response.statusCode})');
    }

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    final tempDir = await getTemporaryDirectory();
    final fileName = isZip ? 'vi_patch.zip' : (isExe ? 'vi_installer.exe' : 'update_file.bin');
    final targetFile = File('${tempDir.path}\\$fileName');
    final sink = targetFile.openWrite();

    onProgress(0.0, 'Đang tải bản cập nhật...');

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        final progress = receivedBytes / totalBytes;
        final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
        final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
        onProgress(progress, 'Đang tải $mbReceived MB / $mbTotal MB (${(progress * 100).toInt()}%)');
      } else {
        onProgress(0.5, 'Đang tải: ${(receivedBytes / 1024).toStringAsFixed(0)} KB');
      }
    }

    await sink.close();
    client.close();

    onProgress(1.0, 'Đang chuẩn bị áp dụng bản vá...');

    if (isExe) {
      // Chạy Installer EXE độc lập và thoát app
      await Process.start(
        targetFile.path,
        [],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } else if (isZip) {
      // Giải nén Zip và dùng batch script để ghi đè vào thư mục app
      final extractDir = Directory('${tempDir.path}\\vi_patch_extracted');
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create();

      onProgress(1.0, 'Đang giải nén file...');

      // Dùng PowerShell Expand-Archive có sẵn trên Windows
      final unzipResult = await Process.run('powershell', [
        '-Command',
        'Expand-Archive',
        '-Path',
        '"${targetFile.path}"',
        '-DestinationPath',
        '"${extractDir.path}"',
        '-Force',
      ]);

      if (unzipResult.exitCode != 0) {
        throw Exception('Giải nén thất bại: ${unzipResult.stderr}');
      }

      // Lấy thư mục cài đặt hiện tại của app
      final appExecutable = Platform.resolvedExecutable;
      final appDir = File(appExecutable).parent.path;

      // Tạo file script update.bat để chờ app thoát rồi ghi đè
      final batFile = File('${tempDir.path}\\vi_apply_update.bat');
      final batContent = '''
@echo off
timeout /t 2 /nobreak > nul
xcopy "${extractDir.path}\\*" "$appDir\\" /E /Y /I > nul
start "" "$appExecutable"
del "%~f0" & exit
''';

      await batFile.writeAsString(batContent);

      onProgress(1.0, 'Khởi động lại để hoàn tất cập nhật...');
      await Future.delayed(const Duration(milliseconds: 500));

      await Process.start(
        'cmd.exe',
        ['/c', batFile.path],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } else {
      throw Exception('Định dạng file tải về không được hỗ trợ (cần .zip hoặc .exe)');
    }
  }

  /// Hiển thị Dialog thông báo cập nhật
  Future<void> showUpdateDialog(BuildContext context, UpdateInfo updateInfo) async {
    double progress = 0.0;
    String statusMessage = '';
    bool isDownloading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: !updateInfo.mandatory && !isDownloading,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.system_update, color: Colors.blue, size: 28),
                  const SizedBox(width: 10),
                  Text('Đã có bản cập nhật mới (v${updateInfo.version})'),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phiên bản hiện tại: v$currentVersion\nPhiên bản mới nhất: v${updateInfo.version} (${updateInfo.releaseDate})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    const Text('Chi tiết thay đổi:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 150),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          updateInfo.changelog.isNotEmpty
                              ? updateInfo.changelog
                              : 'Cải tiến hiệu năng và sửa lỗi.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress > 0 ? progress : null),
                      const SizedBox(height: 8),
                      Text(
                        statusMessage,
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Lỗi: $errorMessage',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!updateInfo.mandatory && !isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Để sau'),
                  ),
                if (!isDownloading)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Cập nhật ngay'),
                    onPressed: () async {
                      setDialogState(() {
                        isDownloading = true;
                        errorMessage = null;
                      });

                      try {
                        await downloadAndApplyUpdate(
                          updateInfo: updateInfo,
                          onProgress: (p, msg) {
                            setDialogState(() {
                              progress = p;
                              statusMessage = msg;
                            });
                          },
                        );
                      } catch (err) {
                        setDialogState(() {
                          isDownloading = false;
                          errorMessage = err.toString();
                        });
                      }
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
