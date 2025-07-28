<?php
// includes/actions/action_ban-ip.php

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/../block-ip.php';

// Check if IP is provided via POST
if (!isset($_POST['ip'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Missing IP address']);
    exit;
}

$ip = trim($_POST['ip']);
$jail = $_POST['jail'] ?? 'unknown';  // Optional, fallback
$source = 'action_ban-ip';            // Fixed source identifier

$result = blockIp($ip, $jail, $source);

if ($result['success']) {
    echo json_encode(['success' => true, 'message' => $result['message']]);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $result['message']]);
}
