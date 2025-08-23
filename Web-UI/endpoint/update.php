<?php
// update.php – Prüft Blocklist-Updates für Client-Server und stellt Blocklists zum Download bereit

header('Content-Type: application/json');

// === Config ===
$CLIENTS_FILE  = "/opt/Fail2Ban-Report/Settings/client-list.json";
$ARCHIVE_ROOT  = __DIR__ . "/../archive/";
$DOWNLOAD_ROOT = __DIR__; // /endpoint/<username>/blocklists/

// === Helper: Antwortfunktion ===
function respond($statusCode, $data) {
    http_response_code($statusCode);
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    exit;
}

// === 1) Authentifizierung ===
if (!file_exists($CLIENTS_FILE)) {
    respond(500, ["success" => false, "message" => "Client list not found."]);
}

$clients = json_decode(file_get_contents($CLIENTS_FILE), true);
if (!is_array($clients)) {
    respond(500, ["success" => false, "message" => "Client list corrupted."]);
}

// POST-Daten
$username = $_POST['username'] ?? '';
$password = $_POST['password'] ?? '';
$uuid     = $_POST['uuid'] ?? '';
$remoteIp = $_SERVER['REMOTE_ADDR'] ?? '';

// Client suchen
$client = null;
foreach ($clients as $c) {
    if ($c['username'] === $username && $c['uuid'] === $uuid) {
        $client = $c;
        break;
    }
}

if (!$client) {
    respond(403, ["success" => false, "message" => "Authentication failed (user/uuid)."]);
}

if (!password_verify($password, $client['password'])) {
    respond(403, ["success" => false, "message" => "Authentication failed (password)."]);
}

if (isset($client['ip']) && $client['ip'] !== $remoteIp) {
    respond(403, ["success" => false, "message" => "Authentication failed (ip mismatch)."]);
}

// === 2) Prüfen, ob Updates für diesen Client vorliegen ===
$updateFile = $ARCHIVE_ROOT . 'update.json';
$update_data = [];
if (file_exists($updateFile)) {
    $update_data = json_decode(file_get_contents($updateFile), true);
    if (!is_array($update_data)) $update_data = [];
}

$clientUpdates = $update_data[$username] ?? [];
$updatesToSend = array_filter($clientUpdates, fn($v) => $v === true);

if (empty($updatesToSend)) {
    respond(200, ["success" => true, "updates" => []]);
}

// === 3) Temporären Download-Pfad vorbereiten ===
$tempDir = $DOWNLOAD_ROOT . "/{$username}/blocklists/";
if (!is_dir($tempDir)) mkdir($tempDir, 0770, true);

// === 4) Blocklists bereitstellen & Status auf false setzen ===
$sentLists = [];

foreach ($updatesToSend as $listName => $_) {
    $sourceFile = $ARCHIVE_ROOT . "$username/blocklists/$listName";
    $destFile   = $tempDir . $listName;

    // Lock auf die Blocklist selbst
    $blockLock = "/tmp/{$listName}.lock";
    $blockHandle = fopen($blockLock, 'c');
    if (!$blockHandle || !flock($blockHandle, LOCK_EX)) {
        continue; // evtl. loggen
    }

    if (file_exists($sourceFile)) {
        copy($sourceFile, $destFile);
        $sentLists[] = $listName;

        // Status in update.json auf false → Lock nur beim Schreiben
        $updateLock = "/tmp/update.json.lock";
        $updateHandle = fopen($updateLock, 'c');
        if ($updateHandle && flock($updateHandle, LOCK_EX)) {
            $update_data[$username][$listName] = false;
            file_put_contents($updateFile, json_encode($update_data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
            flock($updateHandle, LOCK_UN);
            fclose($updateHandle);
        }
    }

    flock($blockHandle, LOCK_UN);
    fclose($blockHandle);
}

// === 5) Antwort an Client ===
respond(200, [
    "success" => true,
    "updates" => $sentLists
]);
