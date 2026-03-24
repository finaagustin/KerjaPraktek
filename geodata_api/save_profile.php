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
$user_id   = isset($_POST['user_id']) ? (int) $_POST['user_id'] : 0;
$full_name = trim($_POST['full_name'] ?? '');
$email     = trim($_POST['email'] ?? '');

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

if ($email !== "" && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode([
        "status" => "error",
        "message" => "Format email tidak valid"
    ]);
    exit;
}

// =========================
// CEK DATA PROFILE
// =========================
$check = $conn->prepare(
    "SELECT id_profil FROM user_profiles WHERE user_id = ?"
);
$check->bind_param("i", $user_id);
$check->execute();
$check->store_result();

// =========================
// INSERT / UPDATE
// =========================
if ($check->num_rows > 0) {
    // UPDATE
    $stmt = $conn->prepare(
        "UPDATE user_profiles
         SET full_name = ?, email = ?
         WHERE user_id = ?"
    );
    $stmt->bind_param("ssi", $full_name, $email, $user_id);
} else {
    // INSERT
    $stmt = $conn->prepare(
        "INSERT INTO user_profiles (user_id, full_name, email)
         VALUES (?, ?, ?)"
    );
    $stmt->bind_param("iss", $user_id, $full_name, $email);
}

// =========================
// EKSEKUSI & RESPONSE
// =========================
if ($stmt->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Profil berhasil disimpan"
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyimpan profil"
    ]);
}

$stmt->close();
$check->close();
$conn->close();
?>
