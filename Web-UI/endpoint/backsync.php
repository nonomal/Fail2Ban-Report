<?php
// backsync.php – Nimmt aktualisierte Blocklists vom Client entgegen und entfernt die Einträge aus update.json

header('Content-Type: application/json');

// === Config ===
$CLIENTS_FILE = "/opt/Fail2Ban-Report/Settings/client-list.json";
$ARCHIVE_ROOT = __DIR__ . "/../archive/";
$UPLOAD_ROOT  = __DIR__; // optional /endpoint/<username>/blocklists/ temporär

// === Helper ===
function respond($statusCode, $data) {
    http_response_code($statusCode);
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    exit;
}

// === 1) Authentifizierung wie index.php ===
if (!file_exists($CLIENTS_FILE)) respond(500, ["success" => false, "message" => "Client list not found."]);
$clients = json_decode(file_get_contents($CLIENTS_FILE), true);
if (!is_array($clients)) respond(500, ["success" => false, "message" => "Client list corrupted."]);

$username = $_POST['username'] ?? '';
$password = $_POST['password'] ?? '';
$uuid     = $_POST['uuid'] ?? '';
$remoteIp = $_SERVER['REMOTE_ADDR'] ?? '';

$client = null;
foreach ($clients as $c) {
    if ($c['username'] === $username && $c['uuid'] === $uuid) { $client = $c; break; }
}
if (!$client || !password_verify($password, $client['password']) || (isset($client['ip']) && $client['ip'] !== $remoteIp)) {
    respond(403, ["success" => false, "message" => "Authentication failed"]);
}

// === 2) Prüfen, ob Datei hochgeladen wurde ===
if (!isset($_FILES['file'])) respond(400, ["success" => false, "message" => "No file uploaded."]);

$uploadedFile = $_FILES['file']['tmp_name'];
$originalName = $_FILES['file']['name'];

if (!is_uploaded_file($uploadedFile)) respond(400, ["success" => false, "message" => "Invalid upload."]);
if (!preg_match('/^[a-z0-9_-]+\.blocklist\.json$/i', $originalName)) {
    respond(400, ["success" => false, "message" => "Invalid filename"]);
}

// === 3) Pfade vorbereiten ===
$userArchive = $ARCHIVE_ROOT . $username . "/blocklists/";
if (!is_dir($userArchive)) mkdir($userArchive, 0770, true);
$targetFile = $userArchive . $originalName;

// === 4) Lock auf Blocklist selbst ===
$blockLock = "/tmp/{$originalName}.lock";
$blockHandle = fopen($blockLock, 'c');
if (!$blockHandle || !flock($blockHandle, LOCK_EX)) {
    respond(500, ["success" => false, "message" => "Could not acquire lock for blocklist"]);
}

// === 5) Alte Datei ersetzen ===
if (!move_uploaded_file($uploadedFile, $targetFile)) {
    flock($blockHandle, LOCK_UN);
    fclose($blockHandle);
    respond(500, ["success" => false, "message" => "Failed to save blocklist"]);
}

// Rechte setzen
chown($targetFile, "root");
chgrp($targetFile, "www-data");

// === 6) Update.json anpassen ===
$updateFile = $ARCHIVE_ROOT . "update.json";
$updateLock = "/tmp/update.json.lock";
$updateHandle = fopen($updateLock, 'c');
if ($updateHandle && flock($updateHandle, LOCK_EX)) {
    $update_data = [];
    if (file_exists($updateFile)) {
        $update_data = json_decode(file_get_contents($updateFile), true);
        if (!is_array($update_data)) $update_data = [];
    }
    if (isset($update_data[$username][$originalName]) && $update_data[$username][$originalName] === false) {
        unset($update_data[$username][$originalName]);
    }
    // falls alle Einträge entfernt → Server-Key löschen
    if (empty($update_data[$username])) unset($update_data[$username]);

    file_put_contents($updateFile, json_encode($update_data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    flock($updateHandle, LOCK_UN);
    fclose($updateHandle);
}

flock($blockHandle, LOCK_UN);
fclose($blockHandle);

respond(200, ["success" => true, "message" => "Blocklist synced successfully"]);
