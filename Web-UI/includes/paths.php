<?php
// Use existing Session or start a new one
if (session_status() === PHP_SESSION_NONE) {
    require_once __DIR__ . '/auth.php';
}

// Config Pfad
$CONFIG_ROOT = "/opt/Fail2Ban-Report/Settings/";

// Basepath
$ARCHIVE_ROOT = __DIR__ . "/../archive/";

// generate serverlist
$SERVERS = [];
if (is_dir($ARCHIVE_ROOT)) {
    foreach (scandir($ARCHIVE_ROOT) as $entry) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }
        if (is_dir($ARCHIVE_ROOT . $entry)) {
            // z. B. Key = Ordnername, Value = "Schönschreibweise"
            $SERVERS[$entry] = ucfirst($entry);
        }
    }
}

// read config
$configFile = $CONFIG_ROOT . 'fail2ban-report.config';
$config = parse_ini_file($configFile, true);

// set standard from config
$configDefault = $config['Default Server']['defaultserver'] ?? null;

// fallback if no standardserver is set in config
if ($configDefault && array_key_exists($configDefault, $SERVERS)) {
    $DEFAULT_SERVER = $configDefault;
} else {
    $DEFAULT_SERVER = array_key_first($SERVERS);
}

// If choosen item -> dont forget
if (isset($_POST['server']) && array_key_exists($_POST['server'], $SERVERS)) {
    $_SESSION['active_server'] = $_POST['server'];
}

// active server (Session → Default)
$activeServer = (isset($_SESSION['active_server']) && array_key_exists($_SESSION['active_server'], $SERVERS))
    ? $_SESSION['active_server']
    : $DEFAULT_SERVER;

/**
 * get paths for the currently active server
 */
function getPaths($server) {
    global $ARCHIVE_ROOT;
    $base = $ARCHIVE_ROOT . $server . "/";
    return [
        "fail2ban"   => $base . "fail2ban/",
        "blocklists" => $base . "blocklists/",
        "ufw"        => $base . "ufw/",
    ];
}

// Global PATHS-Variable
$PATHS = getPaths($activeServer);
$PATHS['config'] = $CONFIG_ROOT;
