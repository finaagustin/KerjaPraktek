<?php
header("Content-Type: application/json");
include "config.php";

// =========================
// VALIDASI METHOD
// =========================
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    echo json_encode([
        "status" => "error",
        "message" => "Request harus menggunakan GET"
    ]);
    exit;
}

// =========================
// VALIDASI PARAMETER
// =========================
$user_id = isset($_GET['user_id']) ? (int) $_GET['user_id'] : 0;

if ($user_id <= 0) {
    echo json_encode([
        "status" => "error",
        "message" => "Parameter user_id tidak valid"
    ]);
    exit;
}

// QUERY DATA PROFILE
$stmt = $conn->prepare(
    "SELECT full_name, email
     FROM user_profiles
     WHERE user_id = ?"
);
$stmt->bind_param("i", $user_id);
$stmt->execute();

$result = $stmt->get_result();
$profile = $result->fetch_assoc();

$stmt->close();
$conn->close();

// RESPONSE
if ($profile) {
    echo json_encode([
        "status" => "success",
        "profile" => $profile
    ]);
} else {
    // profil belum dibuat
    echo json_encode([
        "status" => "success",
        "profile" => [
            "full_name" => "",
            "email" => ""
        ]
    ]);
}
?>
