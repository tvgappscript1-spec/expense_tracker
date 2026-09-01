# Build APK bằng GitHub Actions (thay thế Firebase Studio)

> **Bối cảnh:** Firebase Studio (tiền thân là Project IDX) đã khoá đăng ký người
> dùng mới từ 22/06/2026 và sẽ đóng hẳn ngày 22/03/2027. Tài liệu này thay thế
> hoàn toàn hướng dẫn cũ.

**Nguyên lý:** anh chỉ cần upload mã nguồn lên GitHub. Máy chủ của GitHub sẽ tự
cài Flutter, tự sinh thư mục `android/`, tự build APK và cho anh tải về. Laptop
của anh **không cần cài gì cả** ngoài trình duyệt.

Miễn phí: repo public không giới hạn phút build; repo private được 2.000 phút/tháng
(1 lần build tốn ~8 phút).

---

## Bước 1 — Tạo tài khoản GitHub

1. Vào `https://github.com/signup`
2. Đăng ký bằng email (nên dùng email cá nhân, không dùng email công ty).
3. Xác thực email.

---

## Bước 2 — Tạo repository

1. Vào `https://github.com/new`
2. Điền:
   - **Repository name:** `expense-tracker`
   - Chọn **Private** (mã nguồn riêng của anh)
   - **KHÔNG** tick "Add a README file"
3. Bấm **Create repository**.

---

## Bước 3 — Upload mã nguồn

1. Giải nén `expense_tracker_source.zip` trên máy tính. Anh sẽ có thư mục
   `expense_tracker` chứa: `lib/`, `android/`, `.github/`, `pubspec.yaml`...
2. Trong trang repo vừa tạo, bấm link **uploading an existing file**.
3. **Mở thư mục `expense_tracker` ra**, chọn **toàn bộ nội dung bên trong** rồi
   kéo–thả vào ô upload.

   > Kéo *nội dung bên trong*, không kéo cả thư mục cha. Trên cây thư mục GitHub
   > phải thấy `lib` và `pubspec.yaml` nằm ở tầng ngoài cùng.

4. Ô **Commit changes** gõ: `Khoi tao du an`
5. Bấm **Commit changes**.

### Kiểm tra file ẩn `.github`

Windows/macOS hay giấu thư mục bắt đầu bằng dấu chấm. Sau khi upload, nhìn cây
thư mục trên GitHub — **phải thấy thư mục `.github`**. Nếu không thấy:

1. Bấm **Add file → Create new file**
2. Ô tên file gõ chính xác: `.github/workflows/build-apk.yml`
   (gõ dấu `/` là GitHub tự tạo thư mục con)
3. Mở file `build-apk.yml` trong gói zip bằng Notepad, copy toàn bộ, dán vào.
4. **Commit changes**.

---

## Bước 4 — Chạy build

1. Vào tab **Actions** trên repo.
2. Lần đầu GitHub hỏi bật workflow → bấm **I understand my workflows, go ahead
   and enable them**.
3. Cột trái chọn **Build APK** → bên phải bấm **Run workflow** → **Run workflow**.
4. Đợi ~8–12 phút. Một dòng có vòng tròn vàng đang quay sẽ xuất hiện; bấm vào để
   xem log từng bước theo thời gian thực.

Xong thì dấu tick xanh ✅ hiện lên.

---

## Bước 5 — Tải APK về

1. Bấm vào lần chạy vừa xong.
2. Kéo xuống cuối trang, mục **Artifacts** → có ô **expense-tracker-apk**.
3. Bấm vào để tải file `.zip`.
4. Giải nén, bên trong có 4 file:

| File | Dùng cho |
|---|---|
| `app-arm64-v8a-release.apk` | **Điện thoại Android từ 2019 trở lên — chọn cái này** |
| `app-armeabi-v7a-release.apk` | Máy cũ, RAM thấp |
| `app-x86_64-release.apk` | Máy ảo trên PC |
| `app-release.apk` | Bản dùng chung, chạy mọi máy (nặng hơn) |

Nếu không chắc máy nào, cứ dùng `app-release.apk`.

---

## Bước 6 — Cài lên điện thoại

1. Chép file `.apk` sang điện thoại (Zalo "File của tôi", Google Drive, hoặc cáp USB).
2. Mở file → Android hỏi quyền → **Cài đặt → Cài ứng dụng không rõ nguồn gốc → Cho phép**.
3. Cài xong, mở app. Lần đầu bấm "Quét hoá đơn" sẽ hỏi quyền **Camera** → **Cho phép**.

---

## Sửa code sau này

Không cần build lại thủ công. Chỉ cần:

1. Vào repo → mở file cần sửa (VD `lib/features/home/home_screen.dart`)
2. Bấm icon bút chì ✏️ → sửa → **Commit changes**
3. GitHub **tự động build lại**, vào tab Actions lấy APK mới sau ~10 phút.

---

## Bảng lỗi thường gặp

| Log báo lỗi | Nguyên nhân | Xử lý |
|---|---|---|
| `No such file or directory: pubspec.yaml` | Upload nhầm cả thư mục cha | Xoá hết, upload lại phần **bên trong** thư mục |
| Tab Actions trống trơn | Thiếu thư mục `.github` | Làm lại phần "Kiểm tra file ẩn" ở Bước 3 |
| `version solving failed` | Xung đột package | Workflow đã tự chạy `pub upgrade`; nếu vẫn lỗi, gửi log cho tôi |
| `Execution failed for task ':app:lintVitalRelease'` | Lint chặn build | Thêm vào khối `android { }` trong `build.gradle.kts`: `lint { checkReleaseBuilds = false }` |
| `Missing class com.google.mlkit.vision.text.chinese...` / `minifyReleaseWithR8` | R8 quét thấy code tham chiếu bộ chữ Trung/Nhật/Hàn không nhúng trong APK | Đã xử lý sẵn bằng `proguard-rules.pro` trong workflow. Nếu vẫn lỗi, đổi lệnh build thành `flutter build apk --release --split-per-abi --no-shrink` |
| `Could not resolve com.google.mlkit` | Mạng chập chờn phía GitHub | Bấm **Re-run all jobs** |
| Build quá 30 phút bị cắt | Máy chủ chậm | Bấm **Re-run all jobs** |

---

## Các phương án khác (tham khảo)

| Phương án | Ưu | Nhược |
|---|---|---|
| **GitHub Actions** (khuyên dùng) | Miễn phí, không cài gì, tự động build lại khi sửa code | Sửa code trên web hơi bất tiện |
| **Codemagic** | Chuyên cho Flutter, giao diện dễ, 500 phút/tháng miễn phí | Vẫn phải đẩy code lên Git |
| **Cài Flutter trên máy** | Nhanh nhất, debug trực tiếp, có hot reload | Tốn ~15 GB ổ cứng, cài Android Studio + SDK, máy công ty có thể bị chặn |
| **Google Antigravity** | IDE mới của Google, có AI agent | Vẫn phải tự cài Android SDK ở máy — không giải quyết được vấn đề gốc |
| **Google AI Studio** | Nhanh, có AI | Thiên về web app, **không build được APK Flutter** |
