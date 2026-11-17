<?php

declare(strict_types=1);

define('PROJECT_ROOT', dirname(__DIR__));

$environmentFile = PROJECT_ROOT . '/.env';

if (is_file($environmentFile) && is_readable($environmentFile)) {
    $lines = file($environmentFile, FILE_IGNORE_NEW_LINES);

    if ($lines === false) {
        throw new RuntimeException('The application environment file could not be read.');
    }

    foreach ($lines as $lineNumber => $line) {
        $line = trim($line);

        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }

        $separator = strpos($line, '=');

        if ($separator === false) {
            throw new RuntimeException(sprintf(
                'Invalid environment entry on line %d.',
                $lineNumber + 1
            ));
        }

        $name = trim(substr($line, 0, $separator));
        $value = trim(substr($line, $separator + 1));

        if (!preg_match('/^[A-Z][A-Z0-9_]*$/', $name)) {
            throw new RuntimeException(sprintf(
                'Invalid environment variable name on line %d.',
                $lineNumber + 1
            ));
        }

        if (
            strlen($value) >= 2
            && (($value[0] === '"' && $value[-1] === '"')
                || ($value[0] === "'" && $value[-1] === "'"))
        ) {
            $value = substr($value, 1, -1);
        }

        if (getenv($name) === false) {
            putenv($name . '=' . $value);
            $_ENV[$name] = $value;
        }
    }
}

require_once PROJECT_ROOT . '/includes/functions.php';
require_once PROJECT_ROOT . '/includes/project_images.php';
require_once PROJECT_ROOT . '/includes/service_icons.php';
require_once PROJECT_ROOT . '/includes/session.php';
require_once PROJECT_ROOT . '/includes/flash.php';
require_once PROJECT_ROOT . '/includes/contact_forms.php';
require_once PROJECT_ROOT . '/includes/testimonials.php';
require_once PROJECT_ROOT . '/config/database.php';
