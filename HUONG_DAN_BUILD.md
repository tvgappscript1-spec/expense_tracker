# Hướng dẫn Build & Cập nhật APK

> **Về Project IDX / Firebase Studio:** nền tảng này đã khoá đăng ký người dùng
> mới từ 22/06/2026 và sẽ đóng hẳn ngày 22/03/2027, nên không còn dùng được.
> Toàn bộ quy trình dưới đây chạy trên **GitHub Actions** — miễn phí, không phải
> cài gì lên máy.

---

## PHẦN A — THIẾT LẬP MỘT LẦN DUY NHẤT

### A1. Vì sao bắt buộc phải có keystore

Android chỉ cho phép cài đè bản mới lên bản cũ khi **cả hai được ký bằng cùng
một chữ ký số**. Nếu chữ ký khác nhau, máy báo *"App not installed"* và anh buộc
phải gỡ app — mà **gỡ app là xoá sạch database SQLite**.

Mặc định Flutter ký bản release bằng *debug key*. Mỗi lần GitHub Actions chạy là
một máy ảo mới toanh với debug key khác nhau, nên **mọi bản build đều có chữ ký
khác nhau**. Không xử lý việc này thì mỗi lần cập nhật là mất sạch dữ liệu.

Giải pháp: tạo một keystore cố định, cất trong GitHub Secrets, mọi bản build đều
ký bằng nó.

### A2. Tạo keystore

1. Repo → tab **Actions** → cột trái chọn **1. Tao keystore (chay 1 lan duy nhat)**
2. Bấm **Run workflow** → giữ nguyên mặc định → **Run workflow**
3. Đợi ~1 phút, bấm vào lần chạy vừa xong
4. Mục **Artifacts** ở cuối trang → tải **keystore-CHU-Y-BI-MAT**
5. Giải nén, có 3 file:
   - `upload-keystore.jks` — **file gốc, cất kỹ, mất là hết cứu**
   - `keystore_base64.txt` — bản mã hoá để dán vào Secrets
   - `HUONG_DAN.txt` — chứa mật khẩu đã sinh ngẫu nhiên

Mở luôn bước **"Sinh mat khau ngau nhien va tao keystore"** trong log để đọc mật
khẩu.

### A3. Nạp vào GitHub Secrets

Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

Tạo lần lượt 4 secret:

| Tên secret | Giá trị lấy từ |
|---|---|
| `KEY_ALIAS` | `expense-upload` (hoặc alias anh đã nhập) |
| `KEY_PASSWORD` | Mật khẩu trong `HUONG_DAN.txt` |
| `STORE_PASSWORD` | Cùng mật khẩu đó |
| `KEYSTORE_BASE64` | Mở `keystore_base64.txt`, copy **toàn bộ** nội dung (một dòng rất dài, không xuống dòng) |

### A4. Sao lưu

Chép `upload-keystore.jks` và mật khẩu vào **ít nhất 2 nơi** (Google Drive riêng +
USB). Mất file này đồng nghĩa vĩnh viễn không cập nhật được app đã cài — cách duy
nhất là gỡ đi cài lại, và mất toàn bộ lịch sử chi tiêu.

Sau khi đã nạp Secrets xong, **xoá Artifact keystore trên GitHub** (vào lần chạy
đó → biểu tượng thùng rác cạnh Artifact) để không ai tải được.

---

## PHẦN B — BUILD BẢN ĐẦU TIÊN

1. Tab **Actions** → **Build APK** → **Run workflow**
2. Đợi ~10 phút
3. Vào mục **Releases** ở cột phải trang chính repo → tải `app-arm64-v8a-release.apk`
4. Chép sang điện thoại, bật *Cài ứng dụng không rõ nguồn gốc*, cài đặt

Trong log, bước **"Khoi phuc keystore tu Secrets"** phải in ra dòng
`Keystore da khoi phuc (2xxx bytes)`. Nếu nó in cảnh báo vàng *"Chua co secret
KEYSTORE_BASE64"* nghĩa là Secrets chưa đúng tên — APK build ra vẫn cài được lần
đầu nhưng **không cập nhật được về sau**.

---

## PHẦN C — QUY TẮC CẬP NHẬT APK

### C0. Lệnh build đã có sẵn cờ bắt buộc

Vì danh mục do người dùng tạo được, icon phải lưu bằng codePoint động. Điều này
**bắt buộc** phải có cờ `--no-tree-shake-icons` trong lệnh build, nếu không APK
sẽ báo lỗi khi build hoặc mất icon khi chạy. Workflow đã thêm sẵn cờ này ở cả
hai lệnh build. Nếu tự build tay, nhớ thêm:

```bash
flutter build apk --release --split-per-abi --no-tree-shake-icons
```

### C1. Bắt buộc tăng số build trước mỗi lần phát hành

Mở `pubspec.yaml`, dòng:

```yaml
version: 1.0.0+1
```

Ba số đầu là **versionName** (chỉ để hiển thị cho người dùng đọc). Số sau dấu
`+` là **versionCode** — Android dùng để so sánh mới/cũ. **Luôn phải tăng**,
không bao giờ giảm hay giữ nguyên. Nếu không tăng, máy coi là cùng một bản và
từ chối cài đè.

Quy ước nên theo:

| Loại thay đổi | Ví dụ |
|---|---|
| Sửa lỗi nhỏ | `1.0.0+1` → `1.0.1+2` |
| Thêm tính năng | `1.0.1+2` → `1.1.0+3` |
| Thay đổi lớn | `1.1.0+3` → `2.0.0+4` |

`versionCode` cứ tăng đều 1 đơn vị mỗi lần build, không phụ thuộc `versionName`.

Flutter tự đọc `pubspec.yaml` rồi truyền vào `build.gradle` — anh **không cần
sửa `build.gradle`** bằng tay.

### C2. Quy trình cập nhật

1. Sửa code trên GitHub (mở file → bút chì ✏️ → sửa → Commit)
2. Sửa `pubspec.yaml`, tăng số sau dấu `+`
3. Commit → workflow tự chạy
4. Vào **Releases** tải APK mới
5. Cài đè lên bản cũ — **không cần gỡ app**

### C3. Dữ liệu được giữ nhờ đâu

File `expense_tracker.db` nằm ở `/data/data/<applicationId>/databases/`. Android
**không đụng vào thư mục này** khi cài đè APK. Dữ liệu chỉ mất khi:

- Gỡ app (Uninstall)
- Vào Cài đặt → Ứng dụng → Xoá dữ liệu
- Chữ ký APK khác nhau khiến phải gỡ đi cài lại ← **đã xử lý ở Phần A**

---

## PHẦN D — KHI CẦN ĐỔI CẤU TRÚC DATABASE

Nếu sau này thêm cột hoặc bảng mới, phải viết migration, nếu không app sẽ crash
trên máy đã có dữ liệu cũ.

Mở `lib/services/database_helper.dart`:

**Bước 1** — tăng version:
```dart
static const int _dbVersion = 4;   // đang là 3
```

**Bước 2** — thêm khối mới trong `_onUpgrade`, **không sửa khối cũ**:
```dart
if (oldVersion < 4) {
  await db.execute(
    'ALTER TABLE $tableTransactions ADD COLUMN payment_method '
    "TEXT NOT NULL DEFAULT 'cash'",
  );
}
```

**Bước 3** — cập nhật `toMap()` / `fromMap()` trong model tương ứng.

Nguyên tắc:
- Chỉ dùng `ALTER TABLE ADD COLUMN`, `CREATE TABLE`, `CREATE INDEX`
- Cột mới **phải có `DEFAULT`** để bản ghi cũ không bị NULL
- **Tuyệt đối không** `DROP TABLE` hay `DELETE` trên bảng có dữ liệu thật
- Các khối `if` chạy tuần tự, nên máy đang ở v1 nhảy thẳng lên v4 vẫn được nâng
  đúng thứ tự 1→2→3→4

---

## PHẦN E — CẤU TRÚC MÃ NGUỒN

```
lib/
├── main.dart                        # Provider + Theme + Router + locale vi_VN
├── models/
│   ├── transaction_model.dart       # categoryId (int) trỏ tới danh mục
│   ├── budget_model.dart
│   ├── category_model.dart          # danh mục 2 cấp cha-con
│   └── debt_model.dart              # khoản vay / cho vay
├── services/
│   ├── database_helper.dart         # Singleton, migration v1→v3, seeding, thống kê phân cấp
│   ├── ocr_service.dart             # ML Kit + Regex bóc tách tiền/ngày/đơn vị
│   └── seed/category_seed.dart      # bộ danh mục 2 cấp mặc định
├── providers/
│   ├── expense_provider.dart        # thu chi, ngân sách, lịch, ẩn số dư, thống kê
│   ├── category_provider.dart       # danh mục 2 cấp
│   ├── debt_provider.dart           # sổ nợ, tất toán
│   └── theme_provider.dart          # Chế độ Sáng/Tối, lưu xuống SQLite
├── views/
│   ├── main_screen.dart             # Bottom bar có FAB tròn giữa + 4 tab
│   ├── home_screen.dart             # Dashboard, số dư (ẩn/hiện), ngân sách
│   ├── expense_calendar_screen.dart # Lịch tháng, tổng tiền từng ô ngày
│   ├── debt_screen.dart             # Sổ nợ / cho vay
│   ├── add_transaction_screen.dart  # Form nhập + nút quét OCR
│   ├── budget_setting_screen.dart   # Đặt hạn mức
│   ├── stats_screen.dart            # Biểu đồ tròn phân cấp + cột
│   └── widgets/
│       ├── budget_progress_card.dart
│       ├── summary_card.dart
│       ├── transaction_tile.dart
│       ├── month_selector.dart
│       ├── category_selector_widget.dart
│       └── theme_mode_sheet.dart
└── core/
    ├── constants/app_categories.dart
    ├── theme/app_theme.dart
    └── utils/formatters.dart
```

---

## PHẦN F — BẢNG XỬ LÝ LỖI

| Lỗi | Nguyên nhân | Xử lý |
|---|---|---|
| `App not installed` khi cài đè | Chữ ký khác nhau | Làm Phần A. Bản đã cài bằng debug key phải gỡ 1 lần cuối |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | `versionCode` không tăng | Tăng số sau dấu `+` trong `pubspec.yaml` |
| `Missing class com.google.mlkit...` (R8) | R8 quét thấy bộ chữ Trung/Nhật/Hàn không nhúng | Workflow đã có `proguard-rules.pro`. Nếu vẫn lỗi, thêm `--no-shrink` vào lệnh build |
| `Khong tro duoc release sang keystore that` | Cấu trúc `build.gradle` khác dự kiến | Gửi tôi nội dung `android/app/build.gradle.kts` |
| Tab Actions trống | Thiếu thư mục `.github` khi upload | Tạo thủ công `.github/workflows/build-apk.yml` |
| Lịch không hiện số tiền | Chưa có giao dịch trong tháng | Thêm giao dịch rồi kéo xuống làm mới |
| `LocaleDataException` khi mở lịch | Thiếu nạp locale | Kiểm tra `main.dart` còn dòng `initializeDateFormatting('vi_VN')` không |
| Chọn giao diện xong, mở lại app bị mất | Bảng `settings` chưa tạo | Xem log `flutter run` có dòng `Nâng cấp CSDL: v1 -> v2` không |
