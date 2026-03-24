<?php
header("Content-Type: application/json; charset=UTF-8");
include "config.php";

// =========================
// VALIDASI METHOD
// =========================
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        "status" => "error",
        "message" => "Request harus POST"
    ]);
    exit;
}

// =========================
// AMBIL & BERSIHKAN INPUT
// =========================
$user_id = isset($_POST['user_id']) ? (int) $_POST['user_id'] : 0;
$name    = trim($_POST['location_name'] ?? '');
$desc    = trim($_POST['description'] ?? '');
$lat     = trim($_POST['latitude'] ?? '');
$lng     = trim($_POST['longitude'] ?? '');

// =========================
// VALIDASI DATA
// =========================
if ($user_id <= 0) {
    echo json_encode([
        "status" => "error",
        "message" => "user_id tidak valid"
    ]);
    exit;
}

if ($name === '' || $lat === '' || $lng === '') {
    echo json_encode([
        "status" => "error",
        "message" => "Data lokasi tidak lengkap"
    ]);
    exit;
}

// =========================
// QUERY INSERT
// =========================
$stmt = $conn->prepare(
    "INSERT INTO user_favorites 
     (user_id, location_name, description, latitude, longitude)
     VALUES (?, ?, ?, ?, ?)"
);

if (!$stmt) {
    echo json_encode([
        "status" => "error",
        "message" => "Prepare statement gagal"
    ]);
    exit;
}

$stmt->bind_param(
    "issss",
    $user_id,
    $name,
    $desc,
    $lat,
    $lng
);

// =========================
// EKSEKUSI & RESPONSE
// =========================
if ($stmt->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Lokasi favorit berhasil disimpan"
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyimpan lokasi favorit"
    ]);
}

$stmt->close();
$conn->close();
