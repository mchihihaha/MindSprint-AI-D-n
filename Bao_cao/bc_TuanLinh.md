# Báo cáo cá nhân môn Lập trình Web

- **Sinh viên** Nguyễn Tuấn Linh
- **Tài khoản GitHub** [@tuanlinh0511](https://github.com/tuanlinh0511)
- **Đề tài** Hệ thống hỗ trợ tự học MindSprint AI
- **Ngày đối chiếu** 16/11/2026

Tôi phụ trách migration cơ sở dữ liệu, giao diện đăng nhập dùng chung, dữ liệu mẫu và tính năng ôn tập theo điểm yếu. Tôi cũng bàn giao sơ đồ, kết quả kiểm thử và tài liệu vận hành cơ sở dữ liệu.

## Tính năng và thiết kế đã thực hiện

| Issue | Phần việc thực hiện | Minh chứng |
| --- | --- | --- |
| [#3](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/3) | Phụ trách migration cho sổ tay, nguồn, ghi chú và công việc. Bản hợp nhất có tham chiếu issue; schema các bảng này được lưu trong migration PostgreSQL của phiên bản đó. | [`a78dc4a`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/a78dc4a) |
| [#7](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/7) | Tách giao diện đăng nhập, đăng ký và đăng xuất thành module dùng chung để các tab của ứng dụng dùng cùng phiên đăng nhập. | [`44711ba`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/44711ba) |
| [#15](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/15) | Chuyển bộ từ vựng Kaggle sang dữ liệu seed, sinh mã thẻ ổn định và đối soát thẻ hệ thống cũ. Hồ sơ ghi nhận nhập 1.021 bản ghi và chạy lại seed trên SQLite mà không nhân đôi dữ liệu. | [`a89f322`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/a89f322), [kết quả kiểm thử seed](../docs/architecture/issue-15-seed-data-test-result.md) |
| [#20](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/20) | Cập nhật sơ đồ hoạt động của Kanban, Sổ tay AI và sơ đồ tuần tự của đăng nhập, thẻ học, Sổ tay AI. Bàn giao kết quả đối chiếu mô hình dữ liệu và các sơ đồ. | [`7831946`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/7831946), [hồ sơ đối chiếu UML](../docs/architecture/issue-20-uml-test-result.md) |
| [#35](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/35) | Xây dựng dữ liệu, API và giao diện Điểm yếu. Dùng lịch sử trả lời sai của từng tài khoản để gợi ý chủ đề cần ôn, nêu căn cứ đề xuất và hướng dẫn khi chưa có dữ liệu học. | [`7831946`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/7831946), [`903d26b`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/903d26b), [kết quả kiểm thử Điểm yếu](../docs/architecture/issue-35-weak-areas-test-result.md) |

## Kiểm thử và vận hành dữ liệu

| Issue | Phần việc thực hiện | Minh chứng |
| --- | --- | --- |
| [#48](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/48) | Kiểm thử cập nhật đồng thời trên flashcard và Kanban, kiểm tra cách ứng dụng phát hiện xung đột và bảo toàn thứ tự công việc. | [`18d53a7`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/18d53a7), [báo cáo NFR-07](../docs/architecture/nfr-07-concurrency-test-result.md) |
| [#50](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/50) | Viết quy trình sao lưu/khôi phục PostgreSQL và ghi nhận kết quả diễn tập trên cơ sở dữ liệu thử riêng, gồm đối chiếu số hàng và checksum. | [`30ab83b`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/30ab83b), [báo cáo NFR-09](../docs/architecture/nfr-09-backup-restore-test-result.md) |
| [#53](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/53) | Viết hướng dẫn dựng lại ứng dụng từ bản checkout sạch và bàn giao báo cáo thử trên laptop với PostgreSQL. | [`0876405`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/0876405), [báo cáo dựng lại](../docs/architecture/issue-53-selfhost-test-result.md) |
| [#95](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/95), [#99](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/99), [#102](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/102), [#111](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/111) | Bàn giao script và kết quả sao lưu, kiểm tra migration, khôi phục vào DB riêng và kiểm tra dữ liệu còn sau khi tạo lại container. Các hồ sơ của phần việc này ghi theo bản laptop dùng PostgreSQL. | [`15a0e5a`](https://github.com/tungtungsahul/MindSprint-AI-D-n/commit/15a0e5a), [backup](../docs/architecture/issue-95-backup-test-result.md), [migration](../docs/architecture/issue-99-migration-test-result.md), [restore](../docs/architecture/issue-102-restore-test-result.md), [volume](../docs/architecture/issue-111-volume-persistence-test-result.md) |
