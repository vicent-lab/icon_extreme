<?php

declare(strict_types=1);

function admin_start(string $title): void
{
    $admin = current_admin();
    $role = ucfirst((string) ($admin['role'] ?? 'admin'));
    $sections = [
        'Dashboard' => 'index.php',
        'Projects' => 'manage.php?type=projects',
        'Project images' => 'project-images.php',
        'Services' => 'manage.php?type=services',
        'Testimonials' => 'testimonials.php',
        'Team' => 'manage.php?type=team_members',
        'Blog posts' => 'manage.php?type=blog_posts',
        'Categories' => 'manage.php?type=blog_categories',
        'Messages' => 'manage.php?type=contact_messages',
        'Quote requests' => 'manage.php?type=quote_requests',
        'Company settings' => 'settings.php',
    ];
    ?>
    <!doctype html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="robots" content="noindex, nofollow">
        <title><?= e($title) ?> | ICON Admin</title>
        <link rel="icon" href="<?= e(company_asset_href('company_favicon')) ?>">
        <link rel="stylesheet" href="/assets/css/admin.css">
    </head>
    <body class="admin-body">
        <aside class="admin-sidebar">
            <a class="admin-brand" href="/admin/">
                <img class="admin-brand__logo" src="<?= e(company_asset_href('company_logo')) ?>" alt="">
                <span><?= e(company_setting('company_name')) ?></span>
            </a>
            <p class="admin-sidebar__label">Workspace</p>
            <nav class="admin-nav" aria-label="Admin navigation">
                <?php foreach ($sections as $label => $href): ?>
                    <?php
                    $section = match ($label) {
                        'Projects' => 'projects',
                        'Project images' => 'project_images',
                        'Services' => 'services',
                        'Testimonials' => 'testimonials',
                        'Team' => 'team_members',
                        'Blog posts' => 'blog_posts',
                        'Categories' => 'blog_categories',
                        'Messages' => 'contact_messages',
                        'Quote requests' => 'quote_requests',
                        'Company settings' => 'settings',
                        default => 'dashboard',
                    };
                    if ($section !== 'dashboard' && !admin_can_manage($section)) {
                        continue;
                    }
                    ?>
                    <a href="/admin/<?= e($href) ?>"><?= e($label) ?></a>
                <?php endforeach; ?>
            </nav>
            <div class="admin-sidebar__bottom">
                <a href="/" target="_blank" rel="noopener noreferrer">View website ↗</a>
                <form method="post" action="/admin/logout.php">
                    <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                    <button class="admin-logout" type="submit">Sign out</button>
                </form>
            </div>
        </aside>
        <div class="admin-shell">
            <header class="admin-topbar">
                <span><?= e(company_setting('company_name')) ?></span>
                <span><?= e((string) ($admin['name'] ?? 'Administrator')) ?> <small><?= e($role) ?></small></span>
            </header>
            <main class="admin-main">
                <div class="admin-page-heading"><div><p class="admin-eyebrow">Management workspace</p><h1><?= e($title) ?></h1></div></div>
                <?php foreach (take_flash_messages() as $flash): ?>
                    <div class="admin-alert admin-alert--<?= e($flash['type']) ?>" role="status"><?= e($flash['message']) ?></div>
                <?php endforeach; ?>
    <?php
}

function admin_end(): void
{
    ?>
            </main>
            <footer class="admin-footer">© <?= date('Y') ?> <?= e(company_setting('company_name')) ?></footer>
        </div>
    </body>
    </html>
    <?php
}
