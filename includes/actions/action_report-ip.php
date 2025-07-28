<?php
// includes/actions/action_report.php

// Set response header to JSON with UTF-8 encoding
header('Content-Type: application/json; charset=utf-8');

// Return a dummy response indicating that reporting is not yet implemented
echo json_encode([
    'success' => true,
    'message' => 'Thank you for your report — this feature is not yet implemented and will be available in a future version.'
]);
