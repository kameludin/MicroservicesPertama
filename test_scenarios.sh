#!/usr/bin/env bash
# Skrip pengujian skenario integrasi (Bagian 9 modul praktikum).
# Jalankan setelah `docker compose up --build` aktif di port 8080.
#
# Catatan: Skenario 9 (ketahanan) dan 10 (persistensi) butuh perintah
# docker compose terpisah (stop/down-up) dan diberi jeda manual; skrip ini
# menjalankannya otomatis tapi tetap beri perhatian pada output.

set -uo pipefail
BASE="http://localhost:8080"
pass=0
total=0

check() {
  local desc="$1" expected="$2" actual="$3"
  total=$((total+1))
  if [ "$actual" = "$expected" ]; then
    echo "[OK]   $desc -> $actual"
    pass=$((pass+1))
  else
    echo "[FAIL] $desc -> dapat $actual, diharapkan $expected"
  fi
}

echo "== 1. Tambah mahasiswa =="
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/mahasiswa" \
  -H 'Content-Type: application/json' \
  -d '{"nim":"2210001","nama":"Budi"}')
check "Tambah mahasiswa" 201 "$code"

echo "== 2. NIM duplikat =="
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/mahasiswa" \
  -H 'Content-Type: application/json' \
  -d '{"nim":"2210001","nama":"Budi"}')
check "NIM duplikat" 409 "$code"

echo "== 3. Tambah matkul =="
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/matkul" \
  -H 'Content-Type: application/json' \
  -d '{"kode":"IF304","nama":"Kecerdasan Buatan","sks":3}')
check "Tambah matkul" 201 "$code"

echo "== 4. Ambil matkul =="
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/mahasiswa/2210001/matkul" \
  -H 'Content-Type: application/json' \
  -d '{"kode_mk":"IF301"}')
check "Ambil matkul" 201 "$code"

echo "== 5. Ambil matkul tidak ada =="
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/mahasiswa/2210001/matkul" \
  -H 'Content-Type: application/json' \
  -d '{"kode_mk":"XX999"}')
check "Ambil matkul tidak ada" 404 "$code"

echo "== 6. Ambil matkul dua kali (duplikat) =="
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/mahasiswa/2210001/matkul" \
  -H 'Content-Type: application/json' \
  -d '{"kode_mk":"IF301"}')
check "Ambil matkul dua kali" 409 "$code"

echo "== 7. Lihat KRS =="
echo "GET $BASE/mahasiswa/2210001/matkul:"
curl -s "$BASE/mahasiswa/2210001/matkul"
echo

echo "== 8. Hapus mahasiswa =="
code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/mahasiswa/2210001")
check "Hapus mahasiswa" 204 "$code"

echo "== 9. Ketahanan: matikan matkul-service lalu ambil matkul =="
docker compose stop matkul-service
curl -s -X POST "$BASE/mahasiswa" -H 'Content-Type: application/json' \
  -d '{"nim":"2210002","nama":"Siti"}' >/dev/null
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/mahasiswa/2210002/matkul" \
  -H 'Content-Type: application/json' -d '{"kode_mk":"IF301"}')
check "Ketahanan (matkul-service mati)" 503 "$code"
docker compose start matkul-service
echo "menunggu matkul-service siap kembali..."
sleep 5

echo "== 10. Persistensi: docker compose down lalu up (tanpa -v) =="
docker compose down
docker compose up -d
echo "menunggu service siap..."
sleep 8
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/mahasiswa/2210002")
check "Persistensi data mahasiswa" 200 "$code"

echo
echo "Hasil: $pass / $total skenario sesuai ekspektasi."
