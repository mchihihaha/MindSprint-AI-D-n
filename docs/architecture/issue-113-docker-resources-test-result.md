# Kết quả kiểm thử Issue #113 — Đo tài nguyên và thời gian khởi động bộ Docker

## Thông tin chung
- **Issue:** #113 — [Tuần 1][Laptop] Đo tài nguyên và thời gian khởi động bộ Docker
- **Chủ trì:** Phan Diễn (@phandien665-prog)
- **Reviewer:** mchihihaha / tungtungsahul
- **Mô phôi (Sprint):** Sprint 4 - Tuần 4: Kiểm thử, triển khai, đóng gói
- **Ưu tiên:** P1
- **Hạn:** 20:00 15/11/2026 (Asia/Saigon)
- **Phụ thuộc:** #105, #107, #122

## Baseline
- **Commit:** `f0c3174` (main)
- **Baseline DB:** SQL Server Express 2022 (chuyển đổi từ PostgreSQL theo PR #122 và #124)
- **Môi trường:** Laptop chủ trì, `http://127.0.0.1:8080`, loopback container stack
- **Thành phần:** `compose.selfhost.yaml`, `Dockerfile.selfhost`, `scripts/selfhost.ps1`, `scripts/measure-docker-resources.ps1`

## Tóm tắt kết quả

| Tiêu chí chấp nhận | Kỳ vọng | Thực tế | Kết luận |
|---|---|---|---|
| Đo trên baseline SQL Server Express 2022 | Dùng SQL Server thay PostgreSQL | Image mssql/server:2022-latest và compose.selfhost.yaml | Pass |
| Ghi SHA, image ID và cấu hình máy | Đầy đủ thông số môi trường | Ghi chi tiết SHA, image hash, CPU, RAM, Docker version | Pass |
| Tách thời gian build đầu khỏi cold/warm start | Build no-cache tách riêng thời gian khởi động | Build: 45.82s; Cold start: 13.40s; Warm start: 3.90s | Pass |
| Ghi thời gian tới /healthz và /readyz | Đo chính xác liveness và readiness | /healthz: 3.80s (cold), 1.40s (warm); /readyz: 13.40s (cold), 3.90s (warm) | Pass |
| Đo CPU/RAM khi nghỉ và khi chạy demo | Đo qua docker stats, không tạo tải 20 VU | Nghỉ: ~583 MB RAM (0.3% CPU); Demo: ~777 MB RAM (7.3% CPU) | Pass |
| Đo dung lượng image và volume | Đo dung lượng trên đĩa thực tế | Web: 348 MB; DB: 3.29 GB; Volume: 245 MB; Tổng: ~3.88 GB | Pass |
| Đề xuất cấu hình laptop dựa trên số đo | Cấu hình thực tế đáp ứng SQL Server | Tối thiểu 4 Cores, 8 GB RAM, 10 GB SSD trống | Pass |

## Chi tiết từng tiêu chí

### 1. Baseline SQL Server Express 2022 (P1)
**Kịch bản:** Toàn bộ số đo được thu thập trên bộ stack SQL Server Express 2022 thay cho PostgreSQL cũ theo yêu cầu PR #122.
**Kết quả:**
- Image cơ sở dữ liệu: `mcr.microsoft.com/mssql/server:2022-latest`
- Image ID: `sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`
- Image web: `mindsprint-web:selfhost` (ID: `sha256:2bc1c0f6ba3f46db5945ea3118b990fa3f232c1d3ec135d94eef7601b7e339fb`)
- Base commit kiểm tra: `f0c3174`

### 2. Tách thời gian Build đầu, Cold Start và Warm Start (P1)
**Kịch bản:** Đo thời gian độc lập ở 3 pha riêng biệt:
1. **Build đầu (Clean build, no-cache):** `docker build --no-cache -f Dockerfile.selfhost` mất **45.82 giây**.
2. **Cold Start (Tạo stack mới, volume trống):** Mất **13.40 giây** để toàn bộ stack đạt trạng thái ready.
   - Kestrel Kích hoạt và phản hồi `/healthz` sau **3.80 giây** (`200 ok`).
   - SQL Server khởi động, web chạy EF Core Migrations và seed 955 flashcards hoàn tất, `/readyz` phản hồi sau **13.40 giây** (`200 ready`).
3. **Warm Start (Khởi động lại khi volume đã có schema & dữ liệu):** Mất **3.90 giây**.
   - `/healthz` đạt 200 sau **1.40 giây**.
   - `/readyz` đạt 200 sau **3.90 giây**.

### 3. Phản hồi probe HTTP trong lúc vận hành ổn định (P1)
**Kịch bản:** Gửi HTTP probe qua loopback `127.0.0.1:8080`.
**Kết quả:**
- `/healthz`: **4.53 ms** (`HTTP 200 {"status":"ok"}`)
- `/readyz`: **29.65 ms** (`HTTP 200 {"status":"ready"}`)
- Phục hồi khi DB dừng: `/readyz` trả `503 unavailable` sau 3.99s; khi DB start lại tự động trả `200 ready` sau 5.83s, web giữ nguyên container ID và RestartCount = 0.

### 4. Mức tiêu thụ tài nguyên CPU/RAM và dung lượng lưu trữ (P1)
**Kịch bản:** Đo bằng `docker stats --no-stream` và `docker system df -v`.
**Kết quả:**
- **Lưu trữ:** Web Image 348 MB; DB Image 3.29 GB; Volume `sqlserver-data` 245 MB. Tổng cộng đĩa: **~3.88 GB**.
- **CPU & RAM lúc nghỉ (Idle):**
  - Web: 0.1% CPU, 98 MB RAM
  - DB: 0.2% CPU, 485 MB RAM
  - Toàn stack: **~0.3% CPU, ~583 MB RAM**
- **CPU & RAM lúc chạy Demo thông thường:**
  - Thao tác: CRUD từ vựng, flashcard SRS, tạo task/kanban, notebook/source (không tạo tải 20 VU, không spam Gemini API).
  - Web: 2.8% CPU, 135 MB RAM
  - DB: 4.5% CPU, 642 MB RAM
  - Toàn stack: **~7.3% CPU, ~777 MB RAM**

### 5. Đề xuất cấu hình laptop tối thiểu & khuyến nghị (P1)
- **Tối thiểu:** 4 Cores, 8 GB RAM vật lý (cấp 4 GB cho WSL2), 10 GB SSD trống.
- **Khuyến nghị:** 6–8 Cores, 16 GB RAM vật lý, 20 GB SSD trống.
- **Yêu cầu chủ máy:** Cài Docker Desktop (WSL2), đảm bảo cổng 8080 trống, sinh cấu hình `.env.selfhost` bằng `.\scripts\selfhost.ps1 -Action Configure`.

## Files đã tạo / cập nhật
- `ISSUE-113-REPORT.md`: Báo cáo nghiệm thu chính thức tại root repo.
- `docs/testing/issue-113-docker-resources.md`: Tài liệu báo cáo kỹ thuật trong docs testing.
- `docs/architecture/issue-113-docker-resources-test-result.md`: Bằng chứng kiến trúc chấp nhận (file này).
- `scripts/measure-docker-resources.ps1`: Script tự động đo lường thời gian và tài nguyên container.

## Kết luận
**Pass 100%** — Hoàn thành toàn diện mọi tiêu chí nghiệm thu tuần 09–15/11 được yêu cầu bởi chủ trì và reviewer.

**Người thực hiện:** Phan Diễn (@phandien665-prog)  
**Thời gian:** 15/11/2026, Asia/Saigon  
**Reviewer đối chiếu:** @mchihihaha / @tungtungsahul
