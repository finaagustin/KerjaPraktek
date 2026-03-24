<?php
header("Content-Type: application/json; charset=UTF-8");
include "config.php";

// VALIDASI METHOD
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    echo json_encode([
        "status" => "error",
        "message" => "Request harus menggunakan GET"
    ]);
    exit;
}

// VALIDASI PARAMETER
$user_id = isset($_GET['user_id']) ? (int) $_GET['user_id'] : 0;

if ($user_id <= 0) {
    echo json_encode([
        "status" => "error",
        "message" => "Parameter user_id tidak valid",
        "data" => []
    ]);
    exit;
}

// QUERY DATA FAVORIT
$stmt = $conn->prepare(
    "SELECT 
        id_favorit AS id,
        location_name,
        description,
        latitude,
        longitude
     FROM user_favorites
     WHERE user_id = ?
     ORDER BY id_favorit DESC"
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
    "total"  => count($data),
    "data"   => $data
]);

$stmt->close();
$conn->close();
