# Praktikum: Arsitektur Microservice dengan Python, MySQL, PostgreSQL, dan Nginx API Gateway

Mata Kuliah Sistem Terdistribusi · S1 Informatika · Praktikum kelompok (3 orang)

Proyek ini berisi dua microservice (Mahasiswa & Mata Kuliah), masing-masing
dengan database sendiri (prinsip *database per service*), serta Nginx
sebagai API Gateway dan dashboard sederhana.

## Struktur Folder

```
praktikum-microservice/
├── docker-compose.yml         (Peserta C)
├── gateway/                   (Peserta C)
│   ├── Dockerfile
│   ├── default.conf
│   └── dashboard/index.html
├── mahasiswa-service/         (Peserta A)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py
└── matkul-service/            (Peserta B)
    ├── Dockerfile
    ├── requirements.txt
    └── app.py
```

## Persiapan

Pasang Docker + Docker Compose v2, Git, dan curl/Postman. Python lokal
opsional karena semua dijalankan di container.

```bash
docker --version
docker compose version
git --version
```

## Menjalankan Seluruh Sistem

```bash
docker compose up --build
```

Buka **http://localhost:8080** untuk dashboard.

> Jika gateway gagal start dengan galat `host not found in upstream`,
> pastikan kedua service backend sudah berjalan lalu jalankan:
> `docker compose restart gateway`

## Menjalankan Bagian Tertentu (Uji Mandiri)

**Peserta A (Mahasiswa Service + MySQL):**
```bash
docker compose up --build mahasiswa-service mysql-db
curl -X POST localhost:5001/mahasiswa -H 'Content-Type: application/json' \
  -d '{"nim":"2210001","nama":"Budi","email":"budi@mail.com","angkatan":2022}'
curl localhost:5001/mahasiswa
```

**Peserta B (Matkul Service + PostgreSQL):**
```bash
docker compose up --build matkul-service postgres-db
curl localhost:5002/matkul
curl localhost:5002/matkul/IF301
```

## Skenario Integrasi (lewat Gateway, port 8080)

Jalankan skrip `test_scenarios.sh` setelah seluruh sistem berjalan, atau
jalankan manual sesuai tabel di bawah (lihat Bagian 9 modul):

| No | Skenario | Hasil yang diharapkan |
|----|----------|------------------------|
| 1 | Tambah mahasiswa | 201 |
| 2 | NIM duplikat | 409 |
| 3 | Tambah matkul | 201 |
| 4 | Ambil matkul | 201 |
| 5 | Ambil matkul tidak ada | 404 |
| 6 | Ambil matkul dua kali | 409 |
| 7 | Lihat KRS | daftar matkul lengkap |
| 8 | Hapus mahasiswa | 204, KRS ikut terhapus |
| 9 | Ketahanan (matkul-service mati) | 503, bukan crash |
| 10 | Persistensi (`down` lalu `up` tanpa `-v`) | data masih ada |

Dokumentasikan hasil setiap skenario (screenshot/log) untuk laporan.

## Checklist

**A (Mahasiswa Service):** semua endpoint CRUD berjalan, duplikat NIM → 409,
data tetap ada setelah restart container (volume MySQL), tabel dapat dicek:
```bash
docker compose exec mysql-db mysql -umhs_user -pmhs_pass mahasiswa_db -e 'SHOW TABLES;'
```

**B (Matkul Service):** semua endpoint CRUD berjalan, `GET /matkul/{kode}`
mengembalikan 404 untuk kode yang tidak ada, duplikat kode → 409, data awal
(IF301, IF302, IF303) tampil.

**C (Gateway):** `/mahasiswa` dan `/matkul` dapat diakses lewat port 8080,
dashboard dapat CRUD kedua entitas dan mengambil matkul, pesan error dari
backend tampil di dashboard.

## Troubleshooting

| Gejala | Penyebab & solusi |
|---|---|
| Service Python restart terus, log *menunggu database* | MySQL/PostgreSQL masih inisialisasi (normal 10–30 detik pertama). Tunggu. |
| 502 Bad Gateway dari Nginx | Service tujuan belum siap/crash. Cek `docker compose logs mahasiswa-service`. |
| `host not found in upstream` | Container service belum ada saat Nginx start. `docker compose restart gateway`. |
| Galat autentikasi MySQL (`cryptography` diperlukan) | Pastikan `cryptography` ada di `requirements.txt` Peserta A. |
| Perubahan kode tidak berpengaruh | `docker compose up --build`. |
| Port 8080/5001/5002 sudah dipakai | Ubah sisi kiri pemetaan port di `docker-compose.yml`. |
| Ingin mengulang dari data kosong | `docker compose down -v` (menghapus volume database). |
| Nginx tidak menampilkan dashboard terbaru | Bersihkan cache browser, lalu `docker compose up --build gateway`. |

## Catatan Keamanan

Kredensial ditulis langsung di `docker-compose.yml` demi kemudahan
praktikum. Pada sistem nyata gunakan file `.env` atau secret manager.
Pada versi final, port `5001` dan `5002` sebaiknya dihapus agar
satu-satunya pintu masuk adalah gateway.

## Alur Kerja Git (disarankan)

1. Satu orang membuat repositori dan menambahkan dua anggota lain.
2. Setiap orang bekerja di branch sendiri: `feature/mahasiswa`,
   `feature/matkul`, `feature/gateway`.
3. Digabung ke `main` lewat pull request yang dicek anggota lain.
4. Tiap orang hanya mengubah foldernya sendiri agar tidak terjadi konflik.

**Urutan kerja:** (1) semua membaca kontrak API di Bagian 3.1 modul;
(2) A, B, C mengerjakan bagiannya secara paralel; (3) integrasi bersama.
Peserta A dapat menguji CRUD tanpa menunggu B. Fitur pengambilan matkul
baru bisa diuji setelah service B berjalan.

## Tugas Pengayaan (opsional)

- Tambahkan endpoint `/health` di tiap service + `healthcheck` &
  `depends_on: condition: service_healthy` di Docker Compose.
- Tambahkan *rate limiting* di Nginx dengan `limit_req_zone`.
- Tambahkan autentikasi sederhana (API key) yang diperiksa di gateway.
- Jalankan dua replika Matkul Service + konfigurasi upstream Nginx untuk
  load balancing round-robin.
- Ganti `python app.py` dengan Gunicorn untuk server produksi.

## Pertanyaan Analisis (dijawab dalam laporan kelompok)

1. Mengapa tabel `krs` hanya menyimpan `kode_mk` tanpa foreign key ke
   tabel mata kuliah? Apa konsekuensinya bila mata kuliah dihapus setelah
   diambil mahasiswa? Usulkan solusinya.
2. Pada skenario 9, apa yang terjadi saat Matkul Service mati? Jelaskan
   istilah *coupling* dan *single point of failure* terkait hal ini.
3. Apa keuntungan dan kerugian memakai MySQL dan PostgreSQL pada dua
   service berbeda dibanding satu database bersama?
4. Apa peran API Gateway dalam sistem ini? Sebutkan minimal tiga fungsi
   lain yang dapat ditambahkan pada gateway (misalnya autentikasi, rate
   limiting, load balancing).
5. Jika jumlah mahasiswa sangat besar, service mana yang perlu di-scale
   lebih dulu dan bagaimana caranya? Bagaimana peran Nginx dalam
   skenario tersebut?
6. Bandingkan komunikasi sinkron (REST) dengan asinkron (message broker
   seperti RabbitMQ). Kapan masing-masing lebih cocok?

## Luaran dan Penilaian

**Luaran yang dikumpulkan:**
1. Tautan repositori Git (dengan riwayat commit dari ketiga anggota).
2. Laporan singkat berisi arsitektur, bukti pengujian skenario 1–10, dan
   jawaban pertanyaan analisis.
3. Demo langsung di hadapan asisten atau dosen.

| Komponen | Bobot |
|---|---|
| Individu: fungsionalitas bagian masing-masing (CRUD, validasi, kode error) | 30 |
| Individu: kualitas kode dan kontribusi Git | 20 |
| Kelompok: integrasi dan seluruh skenario uji berhasil | 25 |
| Kelompok: demo | 10 |
| Kelompok: laporan dan analisis | 15 |
| **Total** | **100** |
