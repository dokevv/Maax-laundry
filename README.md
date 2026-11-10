# Maxx Laundry · Legah Group

Aplikasi kasir laundry: cucian masuk → dicuci → siap → diambil, pembayaran (tunai/QRIS/transfer + foto bukti),
pengeluaran, kas & tutup shift, pelanggan, struk printer thermal, dan nota WhatsApp.

- **Web (owner, iPad/iPhone):** https://dokevv.github.io/Maax-laundry/
- **APK tablet outlet:** https://github.com/dokevv/Maax-laundry/releases/download/apk-latest/maxx-laundry.apk

## Struktur
| File | Isi |
|---|---|
| `index.html` | Aplikasi (tampilan & logika) |
| `config.js` | Konfigurasi Firebase + email Owner/Outlet |
| `backend.js` | Koneksi Firebase (login & database) |
| `firestore.rules` | Aturan keamanan database (ditempel di Firebase Console) |
| `android-app/` | Aplikasi Android (WebView + cetak Bluetooth langsung) |

Setiap perubahan di branch `main` otomatis diterbitkan ulang (web & APK) lewat GitHub Actions.
