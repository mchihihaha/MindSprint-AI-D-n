# Đo tài nguyên và thời gian khởi động Docker cho Issue #113

Lượt đo trên SQL Server Express 2022 ngày **16/11/2026, 07:36–07:38 (Asia/Saigon)** đạt **Pass**. Smoke test kiểm tra frontend, readiness, đăng nhập, task, flashcard và nguồn sổ tay trên stack Production riêng. Các mốc giờ trong log dùng UTC. [Bằng chứng](evidence/issue-113-docker-resources-2026-11-16.txt)

## Môi trường và nguồn

| Thành phần | Giá trị |
| --- | --- |
| Host | Windows 11 Home Single Language, build 26200 |
| CPU và RAM host | Intel Core Ultra 9 275HX, 24 lõi, 24 luồng, 31,42 GiB RAM |
| Docker và Compose | Docker Desktop với WSL2 kernel 6.18.33.1, Engine/client 29.7.2, Compose 5.5.0 |
| Tài nguyên Docker Engine quan sát được | 24 CPU logic và 15,33 GiB RAM |
| Công cụ smoke test | Python 3.14.0 |
| Revision ứng dụng | `f64ea3072ea370a2f0047187174fcf56bae521dd`, xuất bằng `git archive` |
| Project và cổng thử | `mindsprint-issue113-1bab90eb9d95`, `127.0.0.1:52905` |
| Volume SQL Server | `mindsprint-issue113-1bab90eb9d95_sqlserver-data` |

Log ghi SHA-256 của script đo và script smoke đã dùng. Nhãn `org.opencontainers.image.revision` của image web đang chạy được kiểm tra với revision ứng dụng.

## Thời gian

| Giai đoạn | Thời gian build | `/healthz` HTTP 200 | `/readyz` HTTP 200 |
| --- | ---: | ---: | ---: |
| Build từ Git archive với `--no-cache` | 62,120 giây | | |
| Cold start, volume mới | | 8,163 giây | 8,196 giây |
| Warm start, giữ volume sau `stop web db` | | 6,908 giây | 6,934 giây |

Hai lượt khởi động dùng image đã chuẩn bị và chạy Compose với `--no-build --pull never`. Đồng hồ bắt đầu khi gọi Compose. Script thăm dò hai endpoint trong lúc stack khởi động, nghỉ 200 ms giữa các vòng và ghi mốc lần đầu nhận HTTP 200 với trạng thái tương ứng.

## Dung lượng và mức sử dụng

| Thành phần | Image ID hoặc phương pháp | Dung lượng |
| --- | --- | ---: |
| Image web | `sha256:610c4e91c6e0eff4707c3fb0c0527559737e39fbd976cf9eaadb33f5e2bc1bee` | 163.315.287 byte |
| Image SQL Server | `sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718` | 626.712.917 byte |
| Volume SQL Server | `du -sk /var/opt/mssql` trong container DB | 93.112 KiB |

Dung lượng image lấy từ trường `.Size` của `docker image inspect`. Dung lượng volume tương đương **90,93 MiB**.

| Kịch bản | Số mẫu | CPU web | CPU DB | CPU cộng theo mẫu | RAM cộng theo mẫu |
| --- | ---: | ---: | ---: | ---: | ---: |
| Nghỉ sau warm start | 3 | 0,28–7,64% | 0,94–3,47% | 1,26–11,11% | 923,14–924,43 MiB |
| Demo một người dùng | 6 | 3,36–32,67% | 0,58–4,69% | 3,94–37,36% | 925,21–955,60 MiB |

Bảng ghi khoảng thấp nhất đến cao nhất trong các mẫu `docker stats` của hai container thử. Demo chạy một smoke test tuần tự qua HTTP, nghỉ 0,5 giây trước mỗi request để lấy mẫu lúc thao tác. Stack thử tắt Gemini và Google.

## Tái lập và chuẩn bị laptop

Từ thư mục gốc, dùng PowerShell 7.3 trở lên với Git, tar, Python và Docker Desktop đang chạy ở chế độ Linux containers. Compose cần hỗ trợ `!override` và `up --wait`. [Script đo](../../scripts/measure-docker-resources.ps1)

```powershell
.\scripts\measure-docker-resources.ps1 -Revision f64ea3072ea370a2f0047187174fcf56bae521dd
```

Mỗi lượt ghi `measurement-evidence.txt` và log build trong `output/issue-113-docker-resources/<project>/`. Cổng loopback, project, volume và thông tin xác thực thử được tạo riêng. Script dọn tài nguyên Docker của project thử khi kết thúc. Kết quả ghi `Blocked` khi thiếu công cụ hoặc Engine, `Fail` khi một bước thất bại và `Pass` sau khi đo, smoke test và dọn dẹp thành công.

Để chuẩn bị demo localhost, đề xuất cấp Docker 4 CPU logic, 4 GiB RAM và để trống 10 GiB SSD cho image, volume và cache build. Lượt demo ghi tối đa 955,60 MiB cho hai container và 37,36% CPU theo `docker stats`. Chủ máy cần cài Docker Desktop với WSL2 và mở Docker Desktop trước khi chạy.
