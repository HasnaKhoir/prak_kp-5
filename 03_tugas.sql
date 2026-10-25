SISTEM KASIR

## Konteks Project
- Nama project: kasir-api
- Deskripsi: REST API untuk sistem kasir toko retail. API mengelola produk, kategori, pelanggan, kasir, dan transaksi penjualan beserta item dan metode pembayarannya. Stok produk akan otomatis berkurang saat transaksi dibuat.
- Resource utama (CRUD lengkap): products
- Bahasa dokumentasi dan pesan error: Bahasa Indonesia
- Autentikasi tidak wajib. Tabel users dipakai sebagai data kasir/admin pada transaksi.

## Tech Stack
- Runtime: Node.js (ES Modules) + Express
- Database: PostgreSQL cloud (Neon atau Supabase), bukan database lokal
- Library DB: `pg` (query berparameter)
- Deployment: Vercel (serverless), dengan `vercel.json` yang benar
- Konfigurasi: `dotenv`; sediakan `.env.example` dan pastikan `.env` ada di `.gitignore`

## Skema Database (7 tabel)
1. `users`: id (PK), name, email (unique), role ('admin' | 'kasir'), created_at
2. `categories`: id (PK), name (unique), description
3. `products`: id (PK), category_id (FK -> categories), sku (unique), name, price (integer, rupiah), stock (integer, >= 0), is_active, created_at, updated_at
4. `customers`: id (PK), name, phone (unique, nullable), created_at
5. `payment_methods`: id (PK), name (misal: Tunai, QRIS, Debit)
6. `transactions`: id (PK), invoice_number (unique), user_id (FK -> users), customer_id (FK -> customers, nullable), payment_method_id (FK -> payment_methods), total_amount, paid_amount, change_amount, status ('selesai' | 'dibatalkan'), created_at
7. `transaction_items`: id (PK), transaction_id (FK -> transactions, ON DELETE CASCADE), product_id (FK -> products), quantity, unit_price (harga saat transaksi), subtotal

Relasi:
- categories 1---N products
- users 1---N transactions
- customers 1---N transactions
- payment_methods 1---N transactions
- transactions 1---N transaction_items
- products N---N transactions melalui tabel pivot transaction_items (many-to-many)

Tambahkan CHECK constraint (price >= 0, stock >= 0, quantity > 0) dan index pada kolom FK.

Buat file `schema.sql`, `seed.sql` (minimal 3 kategori, 10 produk, 2 user, 3 pelanggan, 3 metode pembayaran, 3 transaksi contoh), `erd.dbml` (siap ditempel ke dbdiagram.io), dan diagram Mermaid di README.

## Endpoint API
Resource utama: Products (CRUD lengkap)
- GET /products (dukung query `?search=`, `?category_id=`, `?page=`, `?limit=`)
- GET /products/:id
- POST /products
- PUT /products/:id
- PATCH /products/:id/stock (ubah stok saja)
- DELETE /products/:id

Categories
- GET /categories
- GET /categories/:id
- POST /categories
- PUT /categories/:id
- DELETE /categories/:id (tolak dengan 409 jika masih dipakai produk)

Customers
- GET /customers
- POST /customers
- PUT /customers/:id
- DELETE /customers/:id

Users
- GET /users
- POST /users

Payment methods
- GET /payment-methods

Transactions
- GET /transactions (dukung filter `?date=`, `?user_id=`)
- GET /transactions/:id (JOIN: kasir, pelanggan, metode bayar, dan daftar item beserta nama produk)
- POST /transactions (buat transaksi beserta banyak item sekaligus)
- PATCH /transactions/:id/cancel (batalkan transaksi dan kembalikan stok)

Report
- GET /reports/daily-sales?date=YYYY-MM-DD (total penjualan, jumlah transaksi, produk terlaris)

Contoh body POST /transactions:
{
  "user_id": 1,
  "customer_id": 2,
  "payment_method_id": 1,
  "paid_amount": 100000,
  "items": [
    { "product_id": 3, "quantity": 2 },
    { "product_id": 5, "quantity": 1 }
  ]
}

## Aturan Bisnis Transaksi
- POST /transactions harus berjalan dalam satu database transaction (BEGIN/COMMIT/ROLLBACK).
- Ambil harga dari tabel products (jangan percaya harga dari client), simpan ke unit_price.
- Hitung total_amount dan subtotal di server. Hitung change_amount = paid_amount - total_amount.
- Tolak dengan 400 jika stok tidak cukup ("Stok produk [nama] tidak mencukupi"), produk nonaktif, items kosong, atau paid_amount kurang dari total.
- Kurangi stok produk secara atomik (gunakan row lock, misal SELECT ... FOR UPDATE) agar tidak terjadi stok negatif.
- Generate invoice_number otomatis, misal INV-20261025-0001.
- Pembatalan: status berubah menjadi 'dibatalkan', stok dikembalikan, dan transaksi yang sudah dibatalkan tidak bisa dibatalkan lagi (409).

## Aturan API
- Request dan response selalu JSON.
- Status code: 200 (GET/PUT/PATCH/DELETE sukses), 201 (POST sukses), 400 (input tidak valid), 404 (data tidak ditemukan), 409 (konflik: duplikat SKU/email, data masih dipakai), 500 (error server).
- Format sukses: {"message": "...", "data": {...}}
- Format error: {"error": "Produk tidak ditemukan"}
- Validasi semua input (field wajib, tipe, rentang, FK valid). Tangani error unique/foreign key dari PostgreSQL menjadi pesan yang jelas.
- Tambahkan GET / sebagai health check, error handler global, dan handler 404 untuk route yang tidak ada.

## Struktur Kode
```
src/
  config/db.js
  routes/
  controllers/
  services/        # logika transaksi
  middlewares/     # validasi, error handler
  utils/           # invoice generator, response helper
  app.js
api/index.js       # entry point Vercel
vercel.json
schema.sql
seed.sql
erd.dbml
postman_collection.json
.env.example
README.md
```

## Deployment ke Vercel
- Siapkan `vercel.json` dan entry point agar Express berjalan sebagai serverless function.
- Koneksi DB lewat env `DATABASE_URL` dengan SSL; gunakan connection pooling yang aman untuk serverless.
- Jangan hardcode password atau secret.
- Tulis langkah deploy di README: push ke GitHub, import ke Vercel, isi Environment Variables, deploy.

## Pengujian
- Buat `postman_collection.json` yang berisi request untuk SEMUA endpoint, memakai variabel `{{base_url}}`, lengkap dengan contoh body untuk kasus sukses dan error.
- Jalankan server lokal dan uji semua endpoint (sukses dan error) dengan curl atau skrip. Tampilkan ringkasan hasilnya, termasuk skenario: stok tidak cukup, bayar kurang, pembatalan transaksi, dan hapus kategori yang masih dipakai.

## Dokumentasi (README.md)
Isi minimal:
1. Deskripsi singkat project
2. ERD / skema database (diagram Mermaid + penjelasan relasi)
3. Link deployment (placeholder: https://kasir-api.vercel.app)
4. Daftar seluruh endpoint, tiap endpoint memakai format:

### Nama Endpoint
- Method       : POST
- URL          : https://kasir-api.vercel.app/products
- Deskripsi    : Menambahkan produk baru
- Headers      : Content-Type: application/json
- Request Body : { ... }
- Response Sukses (201): { ... }
- Response Error (400): { ... }

5. Cara menjalankan project secara lokal (install, setup .env, jalankan schema dan seed, start server)
6. Bagian "Asumsi" jika ada keputusan desain yang kamu ambil sendiri

## Aturan Kerja
1. Mulai dengan rencana singkat (tabel, relasi, endpoint), lalu langsung implementasi.
2. Jangan menanyakan hal yang bisa kamu putuskan sendiri; catat sebagai asumsi di README.
3. Jangan membuat atau meng-commit file .env berisi kredensial asli.
4. Setelah selesai, jalankan checklist ini dan laporkan statusnya:
   - [ ] 7 tabel dengan relasi foreign key dan pivot many-to-many
   - [ ] Endpoint GET, POST, PUT/PATCH, DELETE tersedia
   - [ ] CRUD lengkap pada resource products
   - [ ] Transaksi atomik, stok berkurang dan kembali saat dibatalkan
   - [ ] Status code dan pesan error tepat
   - [ ] vercel.json dan entry point siap deploy
   - [ ] Postman collection mencakup semua endpoint
   - [ ] README lengkap (deskripsi, ERD, link deploy, daftar endpoint, cara run lokal)
   - [ ] Tidak ada password atau secret di repository
5. Di akhir, ringkas: file yang dibuat, cara menjalankan, dan hal yang harus saya lakukan manual (membuat database cloud, mengisi env di Vercel, deploy, screenshot pengujian).