# Báo cáo kết quả Issue #113 (Cập nhật bổ sung) — [Tuần 1][Laptop] Đo tài nguyên và thời gian khởi động bộ Docker

* **Người thực hiện:** Phan Diễn (`phandien665-prog`)
* **Người review:** `mchihihaha` / `tungtungsahul`
* **Nhánh:** `dien/issue-113-docker-resources` / `main`
* **Ngày cập nhật đo kiểm:** 15/11/2026 (Hạn chốt tuần 1: 20:00 15/11/2026)
* **Milestone:** Sprint 4 - Tuần 4: Kiểm thử, triển khai, đóng gói
* **Kế hoạch laptop:** [Kế hoạch laptop #92](https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/92)
* **Issue:** https://github.com/tungtungsahul/MindSprint-AI-D-n/issues/113
* **Căn cứ yêu cầu bổ sung:** Cập nhật số đo chuyển đổi từ PostgreSQL sang baseline chuẩn **SQL Server Express 2022** theo [PR #122](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/122), [PR #124](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/124) và [PR #125](https://github.com/tungtungsahul/MindSprint-AI-D-n/pull/125).

---

## 1. Cấu hình Môi trường Đo Kiểm Thực Tế

* **Hệ điều hành:** Microsoft Windows 11 Home Single Language (64-bit), Version 23H2 (OS Build 22631)
* **Bộ xử lý:** Intel(R) Core(TM) 5 120U (10 Cores, 12 Logical Processors, Base 1.4 GHz, Max Turbo 5.0 GHz)
* **Bộ nhớ RAM vật lý:** 16 GB RAM (16,344 MB)
* **Nền tảng container:**
  * Docker Desktop với WSL2 Backend (Ubuntu 24.04 LTS, Linux kernel 5.15)
  * Docker Engine / Client: `29.7.2`
  * Docker Compose: `v5.5.0`
* **Công cụ runtime máy chủ:**
  * .NET SDK: `10.0.401` (Target runtime `net8.0`)
  * Node.js: `v24.21.0`
  * Python: `3.14.5`
* **Base commit kiểm tra:** `f0c3174` (Tích hợp PR #122 SQL Server baseline, PR #123 cấu hình localhost, PR #124 Docker context exclusion, PR #125 same-origin)
* **Stack định tuyến:** 2 container theo chuẩn `compose.selfhost.yaml`:
  * `mindsprint-demo-db-1`: Image `mcr.microsoft.com/mssql/server:2022-latest` (Image ID: `sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`)
  * `mindsprint-demo-web-1`: Image `mindsprint-web:selfhost` (Image ID: `sha256:2bc1c0f6ba3f46db5945ea3118b990fa3f232c1d3ec135d94eef7601b7e339fb`)
  * Cổng phục vụ: Loopback `127.0.0.1:8080` (Cô lập bảo mật, không public port SQL Server).

---

## 2. Lệnh Đo Đạc Chuẩn Hóa

Các lệnh được thực hiện độc lập, không dùng cache và không can thiệp xóa dữ liệu giữa chừng để ép số đo:

1. **Đo thời gian build từ source sạch:**
   ```powershell
   $sw = [System.Diagnostics.Stopwatch]::StartNew()
   docker build --progress plain --no-cache -f Dockerfile.selfhost -t mindsprint-web:selfhost .
   $sw.Stop(); Write-Host "Build time: $($sw.Elapsed.TotalSeconds)s"
   ```

2. **Đo thời gian khởi động & probe `/healthz` và `/readyz`:**
   ```powershell
   # Khởi động stack
   .\scripts\selfhost.ps1 -Action Start

   # Đo phản hồi liveness & readiness qua loopback HTTP probe
   curl.exe --silent --show-error --max-time 8 --write-out "`nHTTP: %{http_code} | Total: %{time_total}s" http://127.0.0.1:8080/healthz
   curl.exe --silent --show-error --max-time 8 --write-out "`nHTTP: %{http_code} | Total: %{time_total}s" http://127.0.0.1:8080/readyz
   ```

3. **Đo tài nguyên CPU/RAM khi nghỉ và khi demo:**
   ```powershell
   docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
   ```

4. **Đo dung lượng image và volume:**
   ```powershell
   docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.ID}}"
   docker system df -v
   ```

---

## 3. Kết quả Đo Đạc Thời Gian (Tách Build, Cold Start, Warm Start)

Theo đúng yêu cầu nghiệm thu, thời gian build đầu tiên được tách riêng biệt khỏi Cold Start và Warm Start:

| Giai đoạn đo | Thời gian thực tế | Trạng thái `/healthz` | Trạng thái `/readyz` | Nội dung chi tiết |
|---|:---:|:---:|:---:|---|
| **1. Build đầu từ source sạch (Clean Docker Build)** | **45.82 giây** | N/A | N/A | Multi-stage build gồm: Stage 1 build frontend SPA (`node build.mjs`), Stage 2 build backend .NET Release (`dotnet publish`), Stage 3 đóng gói runtime ASP.NET 8.0 & curl |
| **2. Cold Start (Lần đầu khởi động sau build)** | **13.40 giây** | **3.80 giây** (`200 ok`) | **13.40 giây** (`200 ready`) | SQL Server Express khởi tạo database instance (`master`, `tempdb`, `mindsprint`), web container chờ DB healthy, chạy EF Core Migrations (2 migration SQL Server) và seed 955 flashcards mẫu |
| **3. Warm Start (Khởi động lại khi volume đã có sẵn)** | **3.90 giây** | **1.40 giây** (`200 ok`) | **3.90 giây** (`200 ready`) | Dữ liệu và schema đã tồn tại trong volume `sqlserver-data`. SQL Server hoàn tất recovery DB trong ~2.2s; Web Kestrel sống sau 1.4s; migration check & readyz hoàn thành sau 3.9s |

### Thời gian phản hồi probe khi hệ thống đang vận hành ổn định:
* `GET /healthz`: **4.53 ms** (HTTP 200, phản hồi `{"status":"ok"}`)
* `GET /readyz`: **29.65 ms** (HTTP 200, thực hiện `SELECT 1` vào SQL Server, phản hồi `{"status":"ready"}`)
* Khi giả lập sự cố dừng SQL Server (`docker compose stop db`): `/healthz` vẫn trả HTTP 200 (2.28 ms), `/readyz` ngắt nhanh và trả HTTP 503 (`status=unavailable`) sau 3.99s. Khi DB phục hồi, readyz tự động đạt 200 sau 5.83s mà không làm restart container web.

---

## 4. Kết quả Đo Đạc Dung Lượng và Tiêu Thụ Tài Nguyên

### 4.1. Dung lượng lưu trữ (Storage Footprint)

| Thành phần | Dung lượng trên đĩa | Ghi chú |
|---|:---:|---|
| **Image Web (`mindsprint-web:selfhost`)** | **348 MB** | Multi-stage build tối ưu, loại bỏ SDK và node_modules thừa |
| **Image DB (`mcr.microsoft.com/mssql/server:2022-latest`)** | **3.29 GB** | SQL Server 2022 Express chính thức của Microsoft |
| **Volume dữ liệu (`mindsprint-demo_sqlserver-data`)** | **245 MB** | Chứa database hệ thống, `mindsprint.mdf` (~16MB), transaction log `mindsprint_log.ldf` (~8MB) và dữ liệu seed |
| **Tổng dung lượng đĩa cần thiết** | **~3.88 GB** | Yêu cầu ổ đĩa trống tối thiểu 10 GB cho swap và layer cache |

### 4.2. Mức tiêu thụ CPU & RAM (`docker stats`)

Đo đạc trong hai kịch bản thực tế:
1. **Trạng thái nghỉ (Idle):** Sau khi khởi động thành công, probe readyz đạt 200, không có request người dùng.
2. **Trạng thái Demo thông thường:** Thao tác người dùng thực tế trên trình duyệt localhost: Đăng ký/đăng nhập, xem danh sách thẻ, lật thẻ flashcard SRS, tạo/di chuyển thẻ Kanban, tạo Notebook và xem nguồn tài liệu. *(Tuân thủ nghiêm ngặt phạm vi issue #113: Không tạo tải giả lập 20 VU, không gọi tràn lan API Gemini tốn quota).*

| Container | Trạng thái nghỉ (Idle) | Trạng thái Demo thông thường |
|---|:---:|:---:|
| `mindsprint-demo-web-1` | CPU: **0.1%** \| RAM: **98 MB** | CPU: **2.8%** \| RAM: **135 MB** |
| `mindsprint-demo-db-1` (SQL Server) | CPU: **0.2%** \| RAM: **485 MB** | CPU: **4.5%** \| RAM: **642 MB** |
| **Tổng cộng toàn bộ Stack** | **CPU: ~0.3% \| RAM: ~583 MB** | **CPU: ~7.3% \| RAM: ~777 MB** |

> [!NOTE]
> So với PostgreSQL trước đây (RAM idle stack ~120MB, demo ~160MB), việc chuyển sang SQL Server Express 2022 làm tăng mức tiêu thụ RAM lên khoảng **580MB – 780MB** (SQL Server đệm buffer pool nội bộ). Tuy nhiên mức tiêu thụ này vẫn hoàn toàn nằm trong ngưỡng kiểm soát an toàn cho các laptop cá nhân có RAM từ 8GB trở lên.

---

## 5. Đề Xuất Cấu Hình Laptop Dựa Trên Số Đo Thực Tế

Căn cứ vào số đo thực tế của bộ stack SQL Server Express:

* **Cấu hình tối thiểu (Minimum Requirements):**
  * **CPU:** 4 Cores (x64)
  * **RAM:** Tối thiểu **8 GB** RAM vật lý (cho phép cấp 3 – 4 GB cho WSL2/Docker Desktop)
  * **Đĩa cứng:** Tối thiểu **10 GB SSD** trống (đủ cho 3.3 GB SQL image, 350 MB web image, Docker overlay2 layers và volume database)
* **Cấu hình đề xuất (Recommended):**
  * **CPU:** 6 – 8 Cores (ví dụ: Intel Core i5/Ultra 5 thế hệ 12 trở lên, AMD Ryzen 5 5000 trở lên)
  * **RAM:** **16 GB** RAM vật lý (giúp máy tính chạy đồng thời Docker, IDE và trình duyệt mượt mà không bị swapping)
  * **Đĩa cứng:** 20 GB SSD NVMe trống
* **Phần chủ máy cần tự cài đặt & chuẩn bị:**
  * Cài đặt **Docker Desktop** phiên bản mới nhất với tùy chọn WSL2 backend.
  * Cấu hình file `%USERPROFILE%\.wslconfig` cấp tối thiểu 4 GB RAM cho WSL2 (`memory=4GB`).
  * Đảm bảo cổng `8080` trên loopback `127.0.0.1` không bị ứng dụng khác chiếm dụng.
  * Chạy cấu hình tự sinh secret trước khi start: `.\scripts\selfhost.ps1 -Action Configure`.

---

## 6. Kết luận Nghiệm Thu Bổ Sung

* Các thiếu sót được chỉ ra trong đợt nghiệm thu 09–15/11 đã được khắc phục toàn diện:
  1. Đã chuyển toàn bộ số đo sang baseline chuẩn **SQL Server Express 2022** theo PR #122.
  2. Ghi rõ ràng SHA, image ID, cấu hình máy thử nghiệm, Docker version, các lệnh đo đạc thực tế, kích thước volume/image và CPU/RAM chi tiết.
  3. Đã tách biệt minh bạch thời gian build đầu (45.82s) khỏi Cold Start (13.40s) và Warm Start (3.90s), ghi nhận thời gian chính xác tới `/healthz` và `/readyz`.
  4. Đã cập nhật đề xuất cấu hình laptop thực tế tương ứng với mức tiêu thụ tài nguyên của SQL Server Express.
* **Kết quả:** **PASS 100%**, đáp ứng đầy đủ tiêu chí chấp nhận của Issue #113 và sẵn sàng chốt nghiệm thu tuần 1.
