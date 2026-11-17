<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/config/bootstrap.php';
require_once PROJECT_ROOT . '/includes/admin.php';

function admin_redirect(string $location): void
{
    redirect('/admin/' . ltrim($location, '/'));
}

function admin_post_token_is_valid(): bool
{
    return $_SERVER['REQUEST_METHOD'] === 'POST'
        && verify_admin_csrf($_POST['csrf_token'] ?? null);
}
