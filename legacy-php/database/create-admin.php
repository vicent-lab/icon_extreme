<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once dirname(__DIR__) . '/config/bootstrap.php';

if (
    !function_exists('posix_isatty')
    || !function_exists('exec')
    || !posix_isatty(STDIN)
) {
    fwrite(STDERR, "Run this setup command in an interactive terminal.\n");
    exit(1);
}

$prompt = static function (string $label): string {
    fwrite(STDOUT, $label);
    $value = fgets(STDIN);

    return $value === false ? '' : trim($value);
};

$name = $prompt('Administrator name: ');
$email = strtolower($prompt('Administrator email: '));
$role = $prompt('Role (admin/editor/support) [admin]: ');
$role = $role === '' ? 'admin' : $role;

if (
    $name === ''
    || strlen($name) > 120
    || strlen($email) > 190
    || filter_var($email, FILTER_VALIDATE_EMAIL) === false
    || !in_array($role, ['admin', 'editor', 'support'], true)
) {
    fwrite(STDERR, "Enter a valid name, email and role.\n");
    exit(1);
}

fwrite(STDOUT, 'Password (12 characters minimum): ');
$terminalOutput = [];
$terminalStatus = 1;
exec('stty -echo 2>/dev/null', $terminalOutput, $terminalStatus);
if ($terminalStatus !== 0) {
    fwrite(STDERR, "Could not disable terminal password echo.\n");
    exit(1);
}
try {
    $password = fgets(STDIN);
} finally {
    exec('stty echo 2>/dev/null', $terminalOutput, $terminalStatus);
}
fwrite(STDOUT, PHP_EOL);
$password = $password === false ? '' : rtrim($password, "\r\n");

if (strlen($password) < 12 || strlen($password) > 256) {
    fwrite(STDERR, "Password must be between 12 and 256 characters.\n");
    exit(1);
}

try {
    $statement = db()->prepare(
        'INSERT INTO admins (name, email, password_hash, role)
        VALUES (:name, :email, :password_hash, :role)'
    );
    $statement->execute([
        'name' => $name,
        'email' => $email,
        'password_hash' => password_hash($password, PASSWORD_DEFAULT),
        'role' => $role,
    ]);
    fwrite(STDOUT, "Administrator account created.\n");
} catch (PDOException | RuntimeException $error) {
    error_log('ICON administrator setup failed: ' . $error->getMessage());
    fwrite(STDERR, "Could not create the administrator. Check database setup and whether the email is already in use.\n");
    exit(1);
}
