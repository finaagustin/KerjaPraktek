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
        "activities" => []
    ]);
    exit;
}

// QUERY DATA AKTIVITAS
$stmt = $conn->prepare(
    "SELECT activity, created_at
     FROM user_activity
     WHERE user_id = ?
     ORDER BY created_at DESC"
);

$stmt->bind_param("i", $user_id);
$stmt->execute();

$result = $stmt->get_result();
$data = [];

while ($row = $result->fetch_assoc()) {
    $data[] = $row;
}

// RESPONSE
echo json_encode([
    "status" => "success",
    "activities" => $data
]);

$stmt->close();
$conn->close();
?>
