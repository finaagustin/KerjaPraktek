<?php
header("Access-Control-Allow-Origin: *"); //mengizinkan flutter mengakses API
header("Content-Type: application/json; charset=UTF-8"); //semua response dari API berbentuk JSON (standar REST API agar mudah diproses flutter) dan menggunakan encoding UTF-8
//allow POST(HTTP) from clients(flutter)
header("Access-Control-Allow-Methods: GET, POST, OPTIONS"); //menentukan metode HTTP yang diizinkan: GET(ambil data), POST(kirim data), OPTIONS(preflight request - otomatis dari browser)
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With"); //mengizinkan header terntentu dikirim oleh flutter: Content-Type(JSON), Authorization(token - jika dikembangkan), X-Requested-With(reequest AJAX)

//konfigurasi database
$host = "localhost";
$user = "root";
$pass = "";
$db   = "geodata";
// $db   = "geodata_db";

$conn = new mysqli($host, $user, $pass, $db); //membuka koneksi ke database

if ($conn->connect_error) { //jika database error kirim response JSON error
    http_response_code(500);
    echo json_encode([
        "status" => "failed",
        "message" => "Koneksi database gagal"
    ]);
    exit;
}

$conn->set_charset("utf8"); //mengatur encoding database ke UTF-8
