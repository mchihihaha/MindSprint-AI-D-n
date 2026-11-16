# Báo cáo nghiệm thu Issue #113

Phụ trách **Phan Diễn** (@phandien665-prog). Người đối chiếu theo issue là @mchihihaha. [Issue #113](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/113)

Lượt đo ngày **16/11/2026, 07:36–07:38 (Asia/Saigon)** đạt **Pass** trên Docker Desktop với SQL Server Express 2022. Ứng dụng được build từ `f64ea3072ea370a2f0047187174fcf56bae521dd` và chạy ở chế độ Production trên project, cổng loopback và volume thử riêng. [Log lượt đo](docs/testing/evidence/issue-113-docker-resources-2026-11-16.txt)

| Phép đo | Kết quả |
| --- | ---: |
| Build sạch từ Git archive | 62,120 giây |
| Cold start tới `/healthz` và `/readyz` | 8,163 và 8,196 giây |
| Warm start tới `/healthz` và `/readyz` | 6,908 và 6,934 giây |
| CPU và RAM cao nhất lúc nghỉ, cộng hai container theo từng mẫu | 11,11% và 924,43 MiB |
| CPU và RAM cao nhất trong demo, cộng hai container theo từng mẫu | 37,36% và 955,60 MiB |

Reviewer có thể đối chiếu image ID, dung lượng, các mẫu CPU/RAM và lệnh tái lập. [Báo cáo kỹ thuật](docs/testing/issue-113-docker-resources.md)
