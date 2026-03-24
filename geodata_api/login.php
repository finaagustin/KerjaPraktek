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

// =========================
// VALIDASI FORMAT USERNAME
// =========================
if (!preg_match('/^[a-z0-9_]{4,}$/', $username)) {
    echo json_encode([
        "status" => "error",
        "message" => "Format username tidak valid"
    ]);
    exit;
}

// =========================
// QUERY DATABASE
// =========================
$stmt = $conn->prepare(
    "SELECT id_user, password FROM users WHERE username = ? LIMIT 1"
);
$stmt->bind_param("s", $username);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();
$stmt->close();

// =========================
// CEK AKUN
// =========================
if (!$user) {
    echo json_encode([
        "status" => "error",
        "message" => "Akun tidak ditemukan"
    ]);
    exit;
}

// =========================
// VERIFIKASI PASSWORD
// =========================
if (!password_verify($password, $user['password'])) {
    echo json_encode([
        "status" => "error",
        "message" => "Password salah"
    ]);
    exit;
}

// =========================
// LOGIN BERHASIL
// =========================
echo json_encode([
    "status" => "success",
    "message" => "Login berhasil",
    "user_id" => (int) $user['id_user']
]);

$conn->close();
