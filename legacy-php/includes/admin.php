<?php

declare(strict_types=1);

function admin_csrf_token(): string
{
    if (!isset($_SESSION['admin_csrf']) || !is_string($_SESSION['admin_csrf'])) {
        $_SESSION['admin_csrf'] = bin2hex(random_bytes(32));
    }

    return $_SESSION['admin_csrf'];
}

function verify_admin_csrf(mixed $token): bool
{
    return is_string($_SESSION['admin_csrf'] ?? null)
        && is_string($token)
        && hash_equals($_SESSION['admin_csrf'], $token);
}

function current_admin(): array
{
    return $_SESSION['admin'] ?? [];
}

function require_admin_role(array $roles = ['admin', 'editor', 'support']): void
{
    require_admin();

    try {
        $statement = db()->prepare(
            'SELECT name, role, is_active FROM admins WHERE id = :id LIMIT 1'
        );
        $statement->execute(['id' => current_admin()['id']]);
        $admin = $statement->fetch();
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON admin authorization failed: ' . $error->getMessage());
        http_response_code(503);
        exit('Administrator access is temporarily unavailable.');
    }

    if (!is_array($admin) || (int) $admin['is_active'] !== 1) {
        logout_admin();
        redirect('/admin/login.php');
    }

    $_SESSION['admin']['name'] = $admin['name'];
    $_SESSION['admin']['role'] = $admin['role'];

    if (!in_array($admin['role'], $roles, true)) {
        http_response_code(403);
        exit('You do not have permission to access this page.');
    }
}

function admin_can_manage(string $section): bool
{
    $role = current_admin()['role'] ?? '';

    if ($role === 'admin') {
        return true;
    }

    if ($role === 'editor') {
        return in_array($section, ['projects', 'project_images', 'services', 'testimonials', 'team_members', 'blog_posts', 'blog_categories'], true);
    }

    return $role === 'support' && in_array($section, ['contact_messages', 'quote_requests'], true);
}

function admin_require_manage(string $section): void
{
    require_admin_role();

    if (!admin_can_manage($section)) {
        http_response_code(403);
        exit('You do not have permission to manage this section.');
    }
}

function admin_escape(mixed $value): string
{
    return e((string) $value);
}

function admin_input_string(array $source, string $key): string
{
    return is_string($source[$key] ?? null) ? trim($source[$key]) : '';
}

function admin_valid_datetime_local(string $value): bool
{
    $date = DateTimeImmutable::createFromFormat('!Y-m-d\TH:i', $value);
    $errors = DateTimeImmutable::getLastErrors();

    return $date !== false
        && ($errors === false || ($errors['warning_count'] === 0 && $errors['error_count'] === 0));
}
