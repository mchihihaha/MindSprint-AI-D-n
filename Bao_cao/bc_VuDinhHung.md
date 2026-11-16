# Báo cáo cá nhân môn Lập trình Web

- **Sinh viên** Vũ Đình Hùng
- **Tài khoản GitHub** [@James-Lloyd20](https://github.com/James-Lloyd20)
- **Đề tài** Hệ thống hỗ trợ tự học MindSprint AI
- **Ngày đối chiếu** 16/11/2026

Tôi phụ trách kiểm tra dữ liệu ở giao diện, cải thiện bố cục trên màn hình nhỏ và bổ sung hỏi đáp bằng giọng nói trong Sổ tay AI.

## Công việc đã thực hiện

| Issue | Phần việc thực hiện | Minh chứng |
| --- | --- | --- |
| [#11](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/11) | Kiểm tra email, độ dài mật khẩu, định dạng URL, loại và dung lượng tệp trước khi gửi tới API. Hiển thị lỗi ngay tại trường nhập để người dùng sửa. | [PR #38](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/38), [báo cáo validation](../ISSUE-11-REPORT.md) |
| [#16](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/16) | Điều chỉnh vùng nhập câu hỏi, tùy chọn giọng nói và nút thao tác của Sổ tay AI và Kanban để dùng được trên màn hình nhỏ. Kiểm tra ở 320, 360, 390, 768 và 1.440 px. | [`fdc5343`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/fdc5343), [PR #70](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/70), [kết quả kiểm tra responsive](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/16#issuecomment-6235167136) |
| [#37](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/37) | Tích hợp nhận diện câu hỏi tiếng Việt và chức năng đọc/dừng câu trả lời. Người dùng xem và sửa câu nhận diện trước khi tự gửi. Ô nhập chữ vẫn dùng được khi trình duyệt thiếu hỗ trợ hoặc micro bị từ chối quyền. | [PR #70](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/70), [kết quả kiểm tra giọng nói](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/37#issuecomment-6235167395) |

## Kết quả kiểm tra

PR #70 ghi 44/44 kiểm tra logic và 7/7 bài tích hợp Edge đạt. Bài kiểm tra dùng thao tác cảm ứng và bộ nhận diện giọng nói giả lập. Kiểm chứng trên micro, loa và điện thoại thật còn thiếu. [Hồ sơ kiểm thử](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/70)
