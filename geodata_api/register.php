<?php
header("Content-Type: application/json");
include "config.php";

// =========================
// FUNGSI NORMALISASI INPUT
// =========================
function clean_input($value) {
    return trim(str_replace(["\r", "\n"], "", $value));
}

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
// AMBIL & VALIDASI INPUT
// =========================
$username = strtolower(clean_input($_POST['username'] ?? ''));
$password = clean_input($_POST['password'] ?? '');

if ($username === '' || $password === '') {
    echo json_encode([
        "status" => "error",
        "message" => "Username dan password wajib diisi"
    ]);
    exit;
}

// ✅ SAMAKAN FORMAT USERNAME DENGAN LOGIN
if (!preg_match('/^[a-z0-9_]{4,}$/', $username)) {
    echo json_encode([
        "status" => "error",
        "message" => "Username minimal 4 karakter (huruf, angka, underscore)"
    ]);
    exit;
}

// =========================
// CEK DUPLIKASI USERNAME
// =========================
$stmt = $conn->prepare(
    "SELECT id FROM users WHERE username = ? LIMIT 1"
);
$stmt->bind_param("s", $username);
$stmt->execute();
$stmt->store_result();

if ($stmt->num_rows > 0) {
    echo json_encode([
        "status" => "error",
        "message" => "Username sudah digunakan"
    ]);
    $stmt->close();
    exit;
}
$stmt->close();

// =========================
// HASH PASSWORD (WAJIB)
// =========================
$hash = password_hash($password, PASSWORD_BCRYPT);

// =========================
// INSERT USER
// =========================
$stmt = $conn->prepare(
    "INSERT INTO users (username, password) VALUES (?, ?)"
);
$stmt->bind_param("ss", $username, $hash);

if ($stmt->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Registrasi berhasil"
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Gagal registrasi"
    ]);
}

$stmt->close();
$conn->close();
