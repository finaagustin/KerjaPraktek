<?php
header("Content-Type: application/json; charset=UTF-8");
include "config.php";

// =========================
// VALIDASI METHOD
// =========================
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        "status" => "error",
        "message" => "Method harus POST"
    ]);
    exit;
}

// =========================
// VALIDASI ID FAVORIT
// =========================
$id_favorit = isset($_POST['id']) ? (int) $_POST['id'] : 0;

if ($id_favorit <= 0) {
    echo json_encode([
        "status" => "error",
        "message" => "ID favorit tidak valid"
    ]);
    exit;
}

// =========================
// DELETE DATA
// =========================
$stmt = $conn->prepare(
    "DELETE FROM user_favorites WHERE id_favorit = ?"
);
$stmt->bind_param("i", $id_favorit);

if ($stmt->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Favorit berhasil dihapus"
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menghapus favorit"
    ]);
}

$stmt->close();
$conn->close();
