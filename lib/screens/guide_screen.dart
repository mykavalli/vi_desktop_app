import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hướng dẫn sử dụng'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.grey[50],
        ),
        child: ListView(
          children: [
            _buildHeader('Chào mừng đến với Vi Desktop App'),
            const Text(
              'Hệ thống quản lý nhân sự và chấm công chuyên nghiệp cho doanh nghiệp.',
              style: TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
            const SizedBox(height: 32),
            _buildSection(
              icon: Icons.people,
              title: '1. Quản lý Nhân viên',
              content: [
                '• Họ tên: Nhập tên đầy đủ của nhân viên.',
                '• Mức lương cơ bản: Lương gốc cố định hàng tháng.',
                '• Lương thâm niên: Khoản cộng thêm dựa trên thời gian gắn bó.',
                '• Phụ cấp: Các khoản hỗ trợ thêm (ăn uống, xăng xe...).',
                '• Trạng thái làm việc: Dùng để phân biệt nhân viên đang làm và đã nghỉ.',
              ],
            ),
            _buildSection(
              icon: Icons.calendar_today,
              title: '2. Chấm công hàng ngày',
              content: [
                '• Click vào ô ngày tương ứng để chuyển đổi trạng thái:',
                '  - Công (W): Đi làm bình thường.',
                '  - Phép (P): Nghỉ có phép (vẫn tính lương cơ bản).',
                '  - Không phép (K): Nghỉ không phép.',
                '• Bạn có thể chấm công cho nhiều vị trí công việc và điểm giao dịch khác nhau trong cùng một ngày.',
              ],
            ),
            _buildSection(
              icon: Icons.summarize,
              title: '3. Tổng hợp Bảng lương',
              content: [
                '• Tổng lương = Lương cơ bản + Lương thâm niên + Phụ cấp + (Lương vị trí x Số ngày công).',
                '• Hệ thống tự động tách số ngày làm việc tại từng điểm giao dịch.',
                '• Xuất file Excel: Nhấn nút Xuất Excel để lưu bảng lương về máy tính.',
              ],
            ),
            _buildSection(
              icon: Icons.backup,
              title: '4. Sao lưu & Khôi phục dữ liệu',
              content: [
                '• Sao lưu tự động vào máy: Bạn có thể chọn thư mục lưu trữ mong muốn trong phần "Thiết lập tài khoản".',
                '• Mỗi lần tạo sao lưu, ứng dụng sẽ tạo 1 file .db gắn ngày giờ cụ thể (ví dụ: vi_backup_20260826_180000.db).',
                '• Sao lưu khi thoát: Khi tắt ứng dụng, bạn có thể chọn "Có, sao lưu và thoát" để lưu lại dữ liệu mới nhất.',
                '• Khôi phục dữ liệu: Bạn có thể chọn bất kỳ bản sao lưu cũ nào trong danh sách hoặc nạp file .db từ máy để khôi phục nhanh.',
              ],
            ),
            _buildSection(
              icon: Icons.system_update_alt,
              title: '5. Cập nhật phiên bản mới',
              content: [
                '• Ứng dụng tự động kiểm tra phiên bản mới từ Git repository khi khởi động.',
                '• Bạn cũng có thể kiểm tra thủ công bằng cách nhấn nút "Kiểm tra cập nhật" trong mục Thiết lập tài khoản.',
                '• Nếu có bản vá mới, ứng dụng sẽ tải về và tự động cập nhật rồi khởi động lại nhanh chóng.',
              ],
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey[100]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blueGrey),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lưu ý: Để bảo mật, vui lòng không chia sẻ mật khẩu tài khoản quản trị cho người không có thẩm quyền.',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<String> content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...content.map((line) => Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 4),
            child: Text(
              line,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          )),
        ],
      ),
    );
  }
}
