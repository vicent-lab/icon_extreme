<?php

declare(strict_types=1);

if (session_status() !== PHP_SESSION_ACTIVE) {
    ini_set('session.use_strict_mode', '1');

    $currentSavePath = session_save_path();
    if ($currentSavePath === '' || !is_dir($currentSavePath) || !is_writable($currentSavePath)) {
        session_save_path(sys_get_temp_dir());
    }

    session_set_cookie_params([
        'httponly' => true,
        'secure' => isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
        'samesite' => 'Lax',
        'path' => '/',
    ]);

    if (!session_start()) {
        throw new RuntimeException('The application session could not be started.');
    }
}

function is_admin_authenticated(): bool
{
    return isset($_SESSION['admin']['id']);
}

function login_admin(array $admin): void
{
    if (!isset($admin['id']) || !is_numeric($admin['id']) || (int) $admin['id'] < 1) {
        throw new InvalidArgumentException('A valid admin ID is required.');
    }

    session_regenerate_id(true);
    $_SESSION['admin'] = [
        'id' => (int) $admin['id'],
        'name' => (string) ($admin['name'] ?? ''),
        'role' => (string) ($admin['role'] ?? 'admin'),
    ];
}

function logout_admin(): void
{
    unset($_SESSION['admin'], $_SESSION['admin_csrf']);
    session_regenerate_id(true);
}

function require_admin(): void
{
    if (!is_admin_authenticated()) {
        redirect('/admin/login.php');
    }
}
