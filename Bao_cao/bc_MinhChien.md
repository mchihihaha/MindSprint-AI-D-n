# Báo cáo cá nhân môn Lập trình Web

- **Sinh viên** Nguyễn Minh Chiến
- **Tài khoản GitHub** [@mchihihaha](https://github.com/mchihihaha)
- **Đề tài** Hệ thống hỗ trợ tự học MindSprint AI
- **Ngày đối chiếu** 16/11/2026

Tôi phụ trách vòng đời phiên đăng nhập, đồng bộ dữ liệu người học, cache của Sổ tay AI, bản đề xuất kế hoạch học và kiểm thử tải.

## Công việc đã thực hiện

| Issue | Phần việc thực hiện | Minh chứng |
| --- | --- | --- |
| [#5](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/5) | Bổ sung refresh token, gia hạn phiên và thu hồi phiên đăng nhập. | [`92c4030`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/92c4030) |
| [#9](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/9) | Nối tạo, sửa và xóa thẻ cá nhân với API. Kiểm tra phiên bản khi ghi để phát hiện xung đột khi cùng một thẻ được sửa ở nhiều phiên. | [`04fd540`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/04fd540) |
| [#12](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/12) | Chọn phần nội dung nguồn liên quan trước khi gửi câu hỏi cho AI. Lưu lại kết quả hỏi đáp và học liệu đã sinh để dùng lại khi đầu vào và nguồn vẫn khớp. | [PR #57](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/57), [`78633c0`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/78633c0), [`8f01e35`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/8f01e35) |
| [#14](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/14) | Đồng bộ lịch học, chuỗi ngày học liên tiếp và thống kê theo tài khoản lên máy chủ để truy xuất lại khi đăng nhập trên thiết bị khác. | [`e2564c1`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/e2564c1) |
| [#21](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/21) | Soạn báo cáo về phạm vi MVP, tình trạng tính năng và rủi ro chi phí AI, bảo mật phiên. | [`705d7d0`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/705d7d0) |
| [#35](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/35) | Sửa phần tham chiếu namespace và phương thức bị trùng trong migration của tính năng Điểm yếu do Nguyễn Tuấn Linh triển khai. | [`6a2b20c`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/6a2b20c), [`41211a0`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/41211a0) |
| [#36](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/36) | Nộp bản lập kế hoạch học theo mục tiêu, ngày thi và thời gian rảnh để người dùng xem và chọn nhiệm vụ. Issue đã đóng Hoàn thành. PR đóng khi chưa merge và bản triển khai được lưu trên nhánh của PR. | [PR #71](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/71), [`f0fdef6`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/f0fdef6) |
| [#43](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/43) | Chuẩn bị kịch bản tải, dữ liệu thử và ghi kết quả trên ASP.NET Core với PostgreSQL cục bộ. Lượt smoke ở 50 người dùng ảo **không đạt**, với 18 lỗi trên 798 request và p95 của API đọc flashcard là 4,83 giây. Hồ sơ dừng ở lượt smoke. | [PR #79](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/79), [báo cáo NFR-02](../docs/testing/issue-43-nfr02-report.md) |
