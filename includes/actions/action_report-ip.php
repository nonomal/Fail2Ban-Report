<?php

$ip = $_POST['ip'] ?? null;
$config = parse_ini_file('/opt/Fail2Ban-Report/fail2ban-report.config');

if (!$config['report'] || !$config['report_types'] || !$ip) {
    echo json_encode([
        'success' => false,
        'message' => 'Reporting not enabled or invalid IP.',
        'type' => 'info',
    ]);
    exit;
}

$services = explode(',', $config['report_types']);
$results = [];

foreach ($services as $service) {
    $service = trim($service);
    $script = __DIR__ . "/reports/$service.php";

    if (file_exists($script)) {
        ob_start();
        include $script;
        $response = ob_get_clean();

        $decoded = json_decode($response, true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            $results[$service] = [
                'success' => false,
                'message' => "Invalid JSON response from $service: " . json_last_error_msg(),
                'raw_response' => $response
            ];
        } else {
            $results[$service] = $decoded;
        }

    } else {
        $results[$service] = [
            'success' => false,
            'message' => "$service report script not available",
            'type' => 'error'
        ];
    }
}

// Kombiniere alle Messages zu einer einzigen Meldung
$messages = [];
foreach ($results as $service => $result) {
    if (!empty($result['message'])) {
        $messages[] = $result['message'];
    }
}

$combinedMessage = implode(" | ", $messages);

echo json_encode([
    'success' => true,
    'message' => $combinedMessage ?: 'Reports collected.',
    'data' => $results,
    'type' => 'info',
]);
