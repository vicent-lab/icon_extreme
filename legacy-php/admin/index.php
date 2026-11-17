<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';
require_admin_role();

$counts = [];
$queries = [
    'Total projects' => 'SELECT COUNT(*) FROM projects',
    'Completed projects' => "SELECT COUNT(*) FROM projects WHERE status = 'completed'",
    'Ongoing projects' => "SELECT COUNT(*) FROM projects WHERE status = 'ongoing'",
    'Quote requests' => 'SELECT COUNT(*) FROM quote_requests',
    'Contact messages' => 'SELECT COUNT(*) FROM contact_messages',
    'Blog posts' => 'SELECT COUNT(*) FROM blog_posts',
    'Services' => 'SELECT COUNT(*) FROM services',
    'Testimonials' => 'SELECT COUNT(*) FROM testimonials',
];

try {
    foreach ($queries as $label => $sql) {
        $statement = db()->prepare($sql);
        $statement->execute();
        $counts[$label] = (int) $statement->fetchColumn();
    }

    $recentStatement = db()->prepare(
        'SELECT id, full_name, subject, status, created_at
        FROM contact_messages ORDER BY created_at DESC LIMIT 5'
    );
    $recentStatement->execute();
    $recentMessages = $recentStatement->fetchAll();

    $quoteStatement = db()->prepare(
        'SELECT id, full_name, project_type, status, created_at
        FROM quote_requests ORDER BY created_at DESC LIMIT 5'
    );
    $quoteStatement->execute();
    $recentQuotes = $quoteStatement->fetchAll();
} catch (PDOException | RuntimeException $error) {
    error_log('ICON admin dashboard query failed: ' . $error->getMessage());
    http_response_code(503);
    exit('Dashboard data is temporarily unavailable. Please try again later.');
}

require_once __DIR__ . '/_layout.php';
admin_start('Dashboard');
?>
<section class="admin-stat-grid" aria-label="Company statistics">
    <?php foreach ($counts as $label => $count): ?>
        <?php $link = '/admin/' . match ($label) {
            'Total projects', 'Completed projects', 'Ongoing projects' => 'manage.php?type=projects',
            'Quote requests' => 'manage.php?type=quote_requests',
            'Contact messages' => 'manage.php?type=contact_messages',
            'Blog posts' => 'manage.php?type=blog_posts',
            'Testimonials' => 'testimonials.php',
            default => 'manage.php?type=services',
        }; ?>
        <?php $section = match ($label) {
            'Total projects', 'Completed projects', 'Ongoing projects' => 'projects',
            'Quote requests' => 'quote_requests',
            'Contact messages' => 'contact_messages',
            'Blog posts' => 'blog_posts',
            'Testimonials' => 'testimonials',
            default => 'services',
        }; ?>
        <?php if (admin_can_manage($section)): ?>
            <a class="admin-stat-card" href="<?= e($link) ?>">
        <?php else: ?>
            <div class="admin-stat-card">
        <?php endif; ?>
            <span><?= e($label) ?></span><strong><?= number_format($count) ?></strong>
        <?php if (admin_can_manage($section)): ?></a><?php else: ?></div><?php endif; ?>
    <?php endforeach; ?>
</section>
<div class="admin-two-column">
    <section class="admin-panel">
        <div class="admin-panel__heading"><h2>Recent contact messages</h2><a href="/admin/manage.php?type=contact_messages">View all</a></div>
        <?php if ($recentMessages === []): ?><p class="admin-empty">No contact messages yet.</p><?php else: ?>
            <div class="admin-list">
                <?php foreach ($recentMessages as $message): ?>
                    <a class="admin-list__item" href="/admin/manage.php?type=contact_messages&amp;id=<?= (int) $message['id'] ?>">
                        <strong><?= e($message['full_name']) ?></strong><span><?= e($message['subject'] ?? 'No subject') ?></span>
                        <small><?= e($message['status']) ?> · <?= e($message['created_at']) ?></small>
                    </a>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>
    <section class="admin-panel">
        <div class="admin-panel__heading"><h2>Recent quote requests</h2><a href="/admin/manage.php?type=quote_requests">View all</a></div>
        <?php if ($recentQuotes === []): ?><p class="admin-empty">No quote requests yet.</p><?php else: ?>
            <div class="admin-list">
                <?php foreach ($recentQuotes as $quote): ?>
                    <a class="admin-list__item" href="/admin/manage.php?type=quote_requests&amp;id=<?= (int) $quote['id'] ?>">
                        <strong><?= e($quote['full_name']) ?></strong><span><?= e($quote['project_type']) ?></span>
                        <small><?= e($quote['status']) ?> · <?= e($quote['created_at']) ?></small>
                    </a>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>
</div>
<?php admin_end(); ?>
