# Panduan Host GitHub & Update Otomatis Aplikasi Kasir

Dokumen ini berisi panduan lengkap untuk menaruh kode aplikasi ini di GitHub dan mengatur alur kerja otomatis agar aplikasi kasir di Windows (EXE) dan Android (APK) dapat diperbarui secara otomatis setiap kali Anda melakukan rilis baru.

---

## Cara Kerja Update Otomatis

Aplikasi ini sudah dilengkapi dengan kode `UpdateService` (`lib/services/update_service.dart`).
Mekanisme kerjanya adalah:
1. Setiap kali dibuka, aplikasi akan membaca file konfigurasi `version.json` dari repositori GitHub Anda secara remote (alamat URL: `https://raw.githubusercontent.com/Oossaan/aplikasi_kakimam/main/version.json`).
2. Aplikasi membandingkan versi rilis saat ini dengan versi di `version.json` (contoh: `1.0.1` vs `1.0.2`).
3. Jika terdapat versi yang lebih baru, aplikasi menampilkan dialog konfirmasi update.
4. Ketika pengguna mengeklik tombol **Download**, aplikasi akan mengunduh berkas installer `.exe` (untuk Windows) atau `.apk` (untuk Android) langsung dari GitHub Releases Anda.

---

## Langkah 1: Push Project ke GitHub

Jika project belum berada di GitHub, jalankan perintah berikut di terminal komputer Anda:

```bash
# 1. Inisialisasi Git (jika belum)
git init

# 2. Tambahkan semua file
git add .

# 3. Commit pertama kali
git commit -m "Initial commit: POS & Inventory System"

# 4. Buat repositori baru di GitHub dengan nama: aplikasi_kakimam
# 5. Hubungkan repositori lokal Anda ke GitHub (Ganti dengan URL repo Anda)
git remote add origin https://github.com/Oossaan/aplikasi_kakimam.git

# 6. Push kode ke cabang utama (main)
git branch -M main
git push -u origin main
```

---

## Langkah 2: Menyiapkan File `version.json`

Buat sebuah file bernama `version.json` di **root folder** proyek Anda dengan isi sebagai berikut:

```json
{
  "version": "1.0.1",
  "release_notes": "- Perbaikan UI halaman Piutang\n- Fitur Tutorial Interaktif saat pertama dibuka\n- Halaman Pengaturan yang lebih rapi",
  "apk_url": "https://github.com/Oossaan/aplikasi_kakimam/releases/latest/download/app-release.apk",
  "exe_url": "https://github.com/Oossaan/aplikasi_kakimam/releases/latest/download/inventory_pos_windows.zip",
  "release_date": "2026-06-02"
}
```

> **PENTING**:
> - Ganti `"version"` dengan versi aplikasi saat ini.
> - Pastikan format URL download menunjuk ke aset rilis terbaru GitHub (`releases/latest/download/`).

---

## Langkah 3: Otomatisasi Build dengan GitHub Actions (CI/CD)

Untuk menghindari keharusan membangun (build) APK dan EXE secara manual di laptop Anda lalu mengunggahnya satu per satu, kita bisa menggunakan **GitHub Actions**.

Buat berkas baru di proyek Anda dengan path: `.github/workflows/release.yml`. Masukkan skrip berikut:

```yaml
name: Build and Auto Release

on:
  push:
    tags:
      - 'v*' # Memicu otomatisasi rilis setiap kali Anda membuat tag versi baru, misalnya: v1.0.2

jobs:
  # --- JOB UNTUK ANDROID (APK) ---
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Build APK
        run: flutter build apk --release

      - name: Upload APK Artifact
        uses: actions/upload-artifact@v3
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk

  # --- JOB UNTUK WINDOWS (EXE) ---
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Build Windows Executable
        run: flutter build windows --release

      - name: Compress Windows Output to ZIP
        run: |
          Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath build\windows\x64\runner\inventory_pos_windows.zip

      - name: Upload Windows Artifact
        uses: actions/upload-artifact@v3
        with:
          name: release-windows
          path: build/windows/x64/runner/inventory_pos_windows.zip

  # --- JOB UNTUK MEMBUAT DRAFT RELEASE DI GITHUB ---
  create-release:
    needs: [build-android, build-windows]
    runs-on: ubuntu-latest
    steps:
      - name: Download APK Artifact
        uses: actions/download-artifact@v3
        with:
          name: release-apk

      - name: Download Windows ZIP Artifact
        uses: actions/download-artifact@v3
        with:
          name: release-windows

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            app-release.apk
            inventory_pos_windows.zip
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Langkah 4: Cara Melakukan Pembaruan (Update) Aplikasi

Ketika Anda selesai membuat fitur baru atau memperbaiki bug, lakukan langkah ini untuk merilis versi baru ke pengguna:

1. **Ubah Versi di Proyek Lokal**:
   - Buka `pubspec.yaml` dan naikkan versinya (misal dari `version: 1.0.1` ke `version: 1.0.2`).
   - Buka `version.json` di root folder proyek Anda, lalu ubah nilainya menjadi:
     ```json
     {
       "version": "1.0.2",
       "release_notes": "- Deskripsi fitur baru Anda...",
       "apk_url": "https://github.com/Oossaan/aplikasi_kakimam/releases/latest/download/app-release.apk",
       "exe_url": "https://github.com/Oossaan/aplikasi_kakimam/releases/latest/download/inventory_pos_windows.zip",
       "release_date": "2026-06-02"
     }
     ```

2. **Commit dan Push ke GitHub**:
   ```bash
   git add .
   git commit -m "Update ke versi v1.0.2"
   git push origin main
   ```

3. **Buat Tag Git Baru (Memicu Build Otomatis)**:
   ```bash
   git tag v1.0.2
   git push origin v1.0.2
   ```

4. **Selesai!**
   GitHub Actions akan mendeteksi tag `v1.0.2` baru tersebut, menjalankan kompilasi cloud Android (APK) & Windows (ZIP EXE) secara paralel, lalu mengunggahnya ke halaman rilis GitHub Anda secara publik.
   
   Saat pengguna membuka aplikasi mereka, aplikasi akan otomatis membandingkan versi lokal dengan versi di `version.json` repositori GitHub Anda, menampilkan pemberitahuan update, dan mengunduh berkas rilis terbaru tanpa campur tangan manual Anda lagi!
