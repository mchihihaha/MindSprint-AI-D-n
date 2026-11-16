# Kết quả kiểm thử tài nguyên Docker cho Issue #113

Benchmark ngày **16/11/2026** đạt **Pass** trên SQL Server Express 2022. Lượt đo dùng nguồn ứng dụng `f64ea3072ea370a2f0047187174fcf56bae521dd`. Người đối chiếu theo issue là @mchihihaha. [Issue #113](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/113)

| Tiêu chí | Kết quả |
| --- | --- |
| Baseline và môi trường | Stack Production trên Docker Desktop, project/volume thử và cổng loopback riêng. Log ghi cấu hình host, phiên bản Docker, image ID và SHA. |
| Build và khởi động | Build no-cache được đo riêng. Hai lần khởi động dùng image có sẵn. Lần đầu tạo volume mới, lần sau giữ volume. |
| Liveness và readiness | Cả hai lần khởi động có mốc HTTP 200 và trạng thái `ok` cho `/healthz`, `ready` cho `/readyz`. |
| Tài nguyên | Đo dung lượng từng image và volume. Log ghi 3 mẫu lúc nghỉ và 6 mẫu trong khi smoke test đang chạy. |
| Smoke test và dọn dẹp | Frontend, readiness, đăng nhập và các thao tác dữ liệu đều qua. Container, mạng và volume của lượt thử đã được dọn. |

Reviewer có thể đối chiếu mốc thời gian, số đo tài nguyên và hướng dẫn tái lập với log trực tiếp của lượt chạy. [Báo cáo kỹ thuật](../testing/issue-113-docker-resources.md) · [Bằng chứng #113](../testing/evidence/issue-113-docker-resources-2026-11-16.txt)
