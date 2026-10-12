# Gia sư — Đính kèm đề rồi hỏi trực tiếp (#33)

Trong **Sổ tay AI → Gia sư**, chọn ảnh hoặc tài liệu ở **Đính kèm đề bài**,
sau đó nhập câu hỏi ngắn như **“Giải câu 1”**, **“Vì sao bước này đúng?”** hoặc
**“Kiểm tra câu 2”** rồi gửi. Chọn tệp không tự gọi AI; tệp được gửi cùng câu hỏi.
Giao diện chỉ hiện tên tệp, câu hỏi của bạn và câu trả lời, không chép toàn bộ
nội dung nhận diện vào ô nhập/chat và không yêu cầu xác nhận OCR.

- Hỗ trợ JPG/JPEG, PNG, WebP, PDF, TXT, MD, CSV; tối đa **10 MB**.
- PDF tối đa **20 trang**, gửi nguyên PDF tới Gemini để giữ bố cục, số mũ,
  phân số và hình vẽ, kể cả PDF có chữ, scan hoặc hỗn hợp.
- TXT/MD/CSV dùng UTF-8, tối đa **200.000 ký tự**; không cắt nội dung âm thầm.
- Câu hỏi và bài làm giữ giới hạn **10.000 ký tự** của Gia sư hiện có.

Tệp được giữ trong bộ nhớ trình duyệt để hỏi tiếp, thử lại, kiểm tra bài làm và
tự luyện. **Bỏ tệp đính kèm**, **Bài mới**, đổi sổ tay/tài khoản hoặc tải lại trang
sẽ bỏ tệp. Đổi/bỏ tệp xóa hội thoại và gợi ý cũ để tránh lẫn ngữ cảnh; câu hỏi/bài
làm đang gõ vẫn được giữ. Khi chờ AI, tệp không thể bị thay trong cùng yêu cầu;
kết quả trễ sau đổi sổ tay/tài khoản bị bỏ.

Ở **Kiểm tra bài làm**, nhập câu cần kiểm tra trong Đề bài (ví dụ “Câu 1”) và
bài làm trong vùng riêng. **Tự luyện** cũng dùng được tệp đính kèm; kiểm định gợi
ý độc lập đọc cùng tệp gốc. Khi ảnh/công thức không rõ, Gia sư được yêu cầu hỏi
lại phần thiếu, không đoán. Tệp hỏng, sai định dạng, vượt giới hạn hoặc kết quả
bị ngắt được báo lỗi. Dịch vụ AI có thể đọc/giải sai; có thể hỏi lại hoặc thay tệp.

Backend không lưu tệp vào database, nguồn hoặc ghi chú. Bộ nhập nguồn/URL vẫn
hoạt động như trước. PDF nguồn có lớp chữ vẫn dùng PdfPig ở endpoint nhập nguồn.

## API

`POST /api/notebooks/{id}/tutor/file`, dùng JWT chung, multipart có:

- `file`: tệp gốc.
- `request`: chuỗi JSON theo hợp đồng Gia sư, ví dụ
  `{"question":"Giải câu 1","style":"steps","history":[]}`.

Hỗ trợ `action=solve/check/hint/solution`, cùng lịch sử/bài làm/mức gợi ý hiện có.
Kiểm tra quyền sở hữu trước khi đọc/gọi AI. 400 cho đầu vào không hợp lệ, 404 cho
sổ tay không thuộc tài khoản; 413 khi vượt kích thước request; giữ mã quota,
timeout và retry của Gemini. Thân multipart được thêm 256 KB cho metadata;
giới hạn riêng tệp 10 MB vẫn được kiểm tra phía server.

Trả `TutorReply` như `/tutor`. JSON schema bắt buộc cho lời giải, nhận xét, gợi ý
và kiểm định giúp giữ escape LaTeX đúng; phản hồi JSON hỏng hoặc có ký tự điều
khiển làm hỏng công thức bị từ chối. Câu hỏi gõ tay cũng hiển thị Markdown/LaTeX.

Endpoint `/tutor/ocr` cũ vẫn có để tương thích, giữ các kiểm tra OCR/đọc PDF có chữ;
giao diện mới không gọi endpoint này.

## Kiểm thử

```powershell
dotnet run --project backend/TutorChecks/TutorChecks.csproj -c Release -- --file-tutor
dotnet run --project backend/TutorChecks/TutorChecks.csproj -c Release -- --ocr
dotnet run --project backend/TutorChecks/TutorChecks.csproj -c Release
node --test tests/frontend-session.test.cjs tests/frontend-text.test.cjs backend/TutorChecks/frontend-tutor.test.cjs backend/GoogleAuthChecks/frontend-google.test.cjs
node --test backend/TutorChecks/browser.test.cjs
```

Kiểm tra tự động dùng SQLite trong bộ nhớ, HTTP Gemini/API giả lập và Edge với
hồ sơ riêng. Bao gồm quyền sở hữu, file/request lỗi, chuyển nguyên ảnh/PDF,
UTF-8, công thức, không chép đề ra UI, hỏi tiếp/retry/check/hint, kiểm định đọc
cùng ảnh, thay/bỏ tệp, dữ liệu trễ, XSS và màn hình 320–1440 px.

Kiểm thử Gemini thật tùy chọn, chỉ gửi đề giả lập, dùng cấu hình Gemini cục bộ:

```powershell
node backend/TutorChecks/ocr-fixture.cjs
dotnet run --project backend/TutorChecks/TutorChecks.csproj -c Release -- --live-file-tutor backend/TutorChecks/bin/ocr-fixtures/vietnamese.png
```

Ngày 12/10/2026, Gemini thật đọc trực tiếp PNG/JPG/WebP và PDF scan của đề mẫu,
giải đúng A = 1/2 + √4 = 5/2 với JSON công thức hợp lệ; đề đạo hàm gõ tay cũng
trả Markdown/LaTeX hợp lệ. Tệp mẫu/build trong bin/, được Git bỏ qua. Build có
cảnh báo NU1900 do sandbox không truy cập nguồn kiểm tra lỗ hổng NuGet.

Kiểm tra tự động qua **18/18** file tutor, **58/58** Gia sư, **23/23** OCR tương
thích, **30/30** frontend/session/Google và **13/13** Gemini reliability; browser
integration qua. Backend cục bộ đã khởi động với endpoint mới; request multipart
không đăng nhập trả 401. Nhận xét Gemini thật cho bài đúng/sai/chưa hoàn chỉnh/
thiếu dữ kiện cũng trả được schema mới.

API multimodal theo tài liệu Google: [ảnh](https://ai.google.dev/gemini-api/docs/generate-content/image-understanding),
[PDF](https://ai.google.dev/gemini-api/docs/generate-content/document-processing),
[generationConfig](https://ai.google.dev/api/generate-content).
