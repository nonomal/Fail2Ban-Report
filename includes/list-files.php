<?php

// Path to the config file
$configPath = '/opt/Fail2Ban-Report/fail2ban-report.config';

// Read config file and parse the [Fail2Ban-Daily-List-Settings] section
$config = [];
if (file_exists($configPath)) {
    $config = parse_ini_file($configPath, true);
}

// Default max days to show if not set in config
$maxDays = 7;
if (isset($config['Fail2Ban-Daily-List-Settings']['max_display_days'])) {
    $maxDays = (int)$config['Fail2Ban-Daily-List-Settings']['max_display_days'];
}

$jsonDir = dirname(__DIR__) . '/archive/';

// Filter all matching JSON files by date in filename
$files = array_filter(scandir($jsonDir), function($filename) use ($maxDays, $jsonDir) {
    // Match files like fail2ban-events-YYYYMMDD.json
    if (!preg_match('/^fail2ban-events-(\d{8})\.json$/', $filename, $matches)) {
        return false;
    }

    // Extract date from filename
    $fileDate = DateTime::createFromFormat('Ymd', $matches[1]);
    if (!$fileDate) {
        return false;
    }

    $now = new DateTime();
    $interval = $now->diff($fileDate);

    // Include only files not in the future and within maxDays
    return ($fileDate <= $now) && ($interval->days < $maxDays);
});

// Sort files descending (newest first)
rsort($files);

// Prepare JSON string for JavaScript consumption
$filesJson = json_encode(array_values($files));
