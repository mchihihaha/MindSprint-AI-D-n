# Issue #33 — Đọc đề từ ảnh và PDF scan

Trong **Sổ tay AI → Gia sư**, chọn JPG/JPEG, PNG, WebP hoặc PDF, rồi bấm
**Nhận diện đề**. Đối chiếu tiếng Việt, công thức LaTeX, các dòng/câu với tệp gốc;
sửa trong vùng **Đề đã nhận diện**, rồi bấm **Xác nhận và dùng đề**.
Sau đó chủ động gửi câu hỏi để giải, nhập bài làm riêng để kiểm tra, hoặc tự luyện.
Nhận diện và xác nhận không tự gọi giải bài. Đề mới xóa hội thoại/gợi ý/bài làm cũ.

Tệp tối đa **10 MB**, PDF tối đa **20 trang**, đề tối đa **10.000 ký tự**.
PDF có lớp chữ được đọc bằng PdfPig; PDF có trang scan hoặc hình nhúng được gửi
toàn bộ sang Gemini để giữ công thức/hình và các trang hỗn hợp. Ảnh cũng dùng Gemini
hiện có, không cần dịch vụ hay thư viện OCR mới. Chỉ gửi tệp khi bấm Nhận diện;
giao diện thông báo việc gửi tệp tới AI. Backend không lưu ảnh, PDF hay đề nhận diện
vào nguồn/ghi chú/database. Bộ nhập URL và nguồn tài liệu của #27 giữ nguyên.

Ảnh mờ/ký hiệu không chắc chắn được cảnh báo và đánh dấu `[không rõ]`; cần sửa
dấu này trước khi xác nhận. Trang không đọc được, thiếu trang, nội dung chưa đầy đủ,
JSON lỗi, kết quả bị ngắt và đề quá dài bị từ chối, không âm thầm cắt hoặc lưu đề.
Chọn tệp khác để thử lại, hoặc **Hủy nhập ảnh/PDF** để gõ đề thủ công.
OCR có thể nhận sai; bước đối chiếu/xác nhận vẫn cần thiết ngay cả khi không có cảnh báo.
Kết quả trả về trễ bị bỏ khi hủy, thay tệp, bắt đầu bài mới, đổi sổ tay hoặc tài khoản.

## API

`POST /api/notebooks/{id}/tutor/ocr`, JWT của ứng dụng, `multipart/form-data`,
trường `file`. Kiểm tra quyền sở hữu trước khi đọc/gọi AI.

```json
{
  "text": "Câu 1: Giải $2x + 3 = 11$.",
  "method": "ocr",
  "pageCount": 1,
  "warnings": []
}
```

`method` là `ocr` hoặc `pdf-text`. Không có lời giải trong phản hồi OCR.
Tệp không hợp lệ trả 400; vượt giới hạn thân request trả 413; sổ tay không thuộc
tài khoản trả 404; đề không đọc đủ trả 422; lỗi Gemini giữ mã quota/timeout/bận
và `retryAfterSeconds`, không đăng xuất. Multipart được phép thêm 64 KB overhead;
giới hạn 10 MB của riêng tệp vẫn được kiểm tra phía server.

Gửi **văn bản người dùng đã xác nhận** qua `/api/notebooks/{id}/tutor` hiện có,
dùng `action=solve/check/hint/solution`. Xác nhận là thao tác phía UI;
endpoint giải bài tiếp tục hỗ trợ đề gõ tay, không tạo token xác nhận mới.

## Kiểm chứng

```powershell
dotnet run --project backend/TutorChecks/TutorChecks.csproj -c Release -- --ocr
dotnet run --project backend/TutorChecks/TutorChecks.csproj -c Release
node --test tests/frontend-session.test.cjs tests/frontend-text.test.cjs backend/TutorChecks/frontend-tutor.test.cjs backend/GoogleAuthChecks/frontend-google.test.cjs
node --test backend/TutorChecks/browser.test.cjs
```

C# dùng SQLite trong bộ nhớ và HTTP Gemini giả lập; kiểm tra quyền, loại/dung lượng,
PDF hỏng, tiếng Việt/công thức/nhiều dòng, cảnh báo ảnh mờ, trang thiếu/không đọc được,
giới hạn đề, PDF có chữ, PDF hỗn hợp, JSON schema, kết quả bị ngắt và quota.
Browser dùng Edge headless với hồ sơ riêng, API mô phỏng, kiểm tra sửa/xác nhận,
chặn gửi trước xác nhận kể cả Enter, kiểm tra bài làm, cảnh báo/XSS, hủy và kết quả
trễ, màn hình 320/768/1024/1440 px cùng các luồng Gia sư cũ.

Kiểm thử Gemini thật tùy chọn, chỉ gửi ảnh đề **giả lập** và PDF scan tạo từ ảnh đó,
không gửi dữ liệu người dùng, dùng cấu hình Gemini cục bộ:

```powershell
node backend/TutorChecks/ocr-fixture.cjs
dotnet run --project backend/TutorChecks/TutorChecks.csproj -c Release -- --live-ocr backend/TutorChecks/bin/ocr-fixtures/vietnamese.png
```

Ảnh mẫu PNG/JPG/WebP gồm ba câu tiếng Việt, phương trình, phân số, căn, số mũ và đề nhiều dòng.
Tệp mẫu/build nằm trong `bin/`, được Git bỏ qua. JSON schema và ví dụ escape LaTeX
giúp tránh mất dấu gạch chéo trong công thức; phản hồi sai định dạng vẫn bị từ chối.
API multimodal theo tài liệu chính thức Google:
[ảnh](https://ai.google.dev/gemini-api/docs/generate-content/image-understanding),
[PDF](https://ai.google.dev/gemini-api/docs/generate-content/document-processing),
[generationConfig](https://ai.google.dev/api/generate-content).

Kết quả ngày 12/10/2026: **23/23** kiểm tra OCR C#, **58/58** Gia sư C#,
**29/29** frontend/session/Google, và browser integration qua. Gemini thật đọc
thành công PNG, JPG, WebP và PDF scan của đề mẫu, giữ tiếng Việt, ba câu, phân số
và căn. Build Release không có lỗi; có cảnh báo NU1900 do sandbox không truy cập
được nguồn dữ liệu kiểm tra lỗ hổng NuGet. Không thay đổi database thật.
