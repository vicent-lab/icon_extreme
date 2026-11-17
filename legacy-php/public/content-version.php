<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');

if (
    getenv('DB_HOST') === false
    || getenv('DB_NAME') === false
    || getenv('DB_USER') === false
    || getenv('DB_PASSWORD') === false
) {
    http_response_code(503);
    echo json_encode(['error' => 'Public content version is unavailable.']);
    exit;
}

try {
    echo json_encode(['version' => public_content_version()], JSON_THROW_ON_ERROR);
} catch (PDOException | RuntimeException | JsonException $error) {
    error_log('ICON public content version endpoint failed: ' . $error->getMessage());
    http_response_code(503);
    echo json_encode(['error' => 'Public content version is unavailable.']);
}
