<?php

declare(strict_types=1);

function db(): PDO
{
    static $connection = null;

    if ($connection instanceof PDO) {
        return $connection;
    }

    $host = getenv('DB_HOST');
    $port = getenv('DB_PORT') ?: '3306';
    $database = getenv('DB_NAME');
    $username = getenv('DB_USER');
    $password = getenv('DB_PASSWORD');
    $socket = getenv('DB_SOCKET');

    foreach ([
        'DB_HOST' => $host,
        'DB_NAME' => $database,
        'DB_USER' => $username,
        'DB_PASSWORD' => $password,
    ] as $name => $value) {
        if ($value === false) {
            throw new RuntimeException(sprintf(
                'Missing required environment variable: %s.',
                $name
            ));
        }
    }

    if (!$socket && (!ctype_digit($port) || (int) $port < 1 || (int) $port > 65535)) {
        throw new RuntimeException('DB_PORT must be a valid TCP port.');
    }

    $dsn = $socket
        ? sprintf('mysql:unix_socket=%s;dbname=%s;charset=utf8mb4', $socket, $database)
        : sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4', $host, $port, $database);

    $connection = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);

    return $connection;
}
