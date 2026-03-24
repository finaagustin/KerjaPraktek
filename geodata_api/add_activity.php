<?php
header("Content-Type: application/json");
include "config.php";

// =========================
// VALIDASI METHOD
// =========================
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        "status" => "error",
        "message" => "Request harus menggunakan POST"
    ]);
    exit;
}

// =========================
// AMBIL INPUT
// =========================
$user_id  = isset($_POST['user_id']) ? (int) $_POST['user_id'] : 0;
$activity = trim($_POST['activity'] ?? '');

// =========================
// VALIDASI INPUT
// =========================
if ($user_id <= 0 || $activity === '') {
    echo json_encode([
        "status" => "error",
        "message" => "Data tidak lengkap atau tidak valid"
    ]);
    exit;
}

// =========================
// INSERT DATA
// =========================
$stmt = $conn->prepare(
    "INSERT INTO user_activity (user_id, activity)
     VALUES (?, ?)"
);

if (!$stmt) {
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan query"
    ]);
    exit;
}

$stmt->bind_param("is", $user_id, $activity);

// =========================
// EKSEKUSI & RESPONSE
// =========================
if ($stmt->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Aktivitas berhasil disimpan"
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyimpan aktivitas"
    ]);
}

$stmt->close();
$conn->close();
?>
