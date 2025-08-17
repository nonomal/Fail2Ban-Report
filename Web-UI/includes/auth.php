<?php
// Session starten (mit sicheren Cookie-Flags)
if (session_status() === PHP_SESSION_NONE) {
    session_set_cookie_params([
        'lifetime' => 0,          // Session endet beim Schließen des Browsers
        'path' => '/',
        'httponly' => true,       // Kein Zugriff via JavaScript
        'secure' => true,         // Nur über HTTPS
        'samesite' => 'Strict'    // Kein Cross-Site-Request möglich
    ]);
    session_start();
}

// Timeout-Check direkt nach Session-Start
$SESSION_TIMEOUT = 1800; // 30 Minuten
if (isset($_SESSION['last_activity']) && (time() - $_SESSION['last_activity'] > $SESSION_TIMEOUT)) {
    session_unset();
    session_destroy();
    die("Session expired. Please log in again.");
}
$_SESSION['last_activity'] = time();

// Standardrolle setzen
if (!isset($_SESSION['user_role'])) {
    $_SESSION['user_role'] = 'viewer';
}

// paths.php einbinden, damit $PATHS['config'] existiert
//require_once __DIR__ . '/paths.php';

// User-Datei laden
//$USER_FILE = $PATHS['config'] . "users.json";
$USER_FILE= "/opt/Fail2Ban-Report/Settings/users.json";
$USERS = json_decode(file_get_contents($USER_FILE), true) ?: [];

// Logout verarbeiten
if (isset($_POST['logout'])) {
    session_unset();
    session_destroy();
    header("Location: " . $_SERVER['PHP_SELF']); // Zurück zur Login-Seite
    exit;
}

// Loginformular gesendet?
if (isset($_POST['login_user']) && isset($_POST['login_pass'])) {
    $user = $_POST['login_user'];
    $pass = $_POST['login_pass'];
    $loggedIn = false;

    foreach ($USERS as $u) {
        if ($u['username'] === $user && password_verify($pass, $u['password'])) {
            // Login erfolgreich -> Session fixieren
            session_regenerate_id(true);
            $_SESSION['user_role'] = $u['role'];
            $_SESSION['username']  = $u['username'];
            $loggedIn = true;
            break;
        }
    }

    if (!$loggedIn) {
        // Optional: Loginversuch loggen / Fail2Ban triggern
        error_log("Failed login for $user from " . $_SERVER['REMOTE_ADDR']);
        die("Login failed");
    }
}

// Admin-Check
function is_admin() {
    return (isset($_SESSION['user_role']) && $_SESSION['user_role'] === 'admin');
}

// Optional: Session Debug
function debug_session() {
    echo "<pre>";
    print_r($_SESSION);
    echo "</pre>";
}
?>
