<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

$companyName = company_setting('company_name');
$slug = filter_input(INPUT_GET, 'slug', FILTER_SANITIZE_SPECIAL_CHARS);

$post = null;
$databaseReady = getenv('DB_HOST') !== false
    && getenv('DB_NAME') !== false
    && getenv('DB_USER') !== false
    && getenv('DB_PASSWORD') !== false;

if ($databaseReady && $slug !== false && $slug !== '') {
    try {
        $connection = db();
        $statement = $connection->prepare(
            'SELECT bp.id, bp.title, bp.slug, bp.excerpt, bp.content, bp.featured_image, bp.published_at,
                    bc.name AS category_name
            FROM blog_posts bp
            LEFT JOIN blog_categories bc ON bp.category_id = bc.id
            WHERE bp.slug = :slug AND bp.status = :status
            LIMIT 1'
        );
        $statement->execute(['slug' => $slug, 'status' => 'published']);
        $post = $statement->fetch() ?: null;
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON blog post database query failed: ' . $error->getMessage());
    }
}

if ($post === null) {
    http_response_code(404);
    $pageTitle = 'Article Not Found | ' . $companyName;
    $pageDescription = 'The requested article is not available.';
} else {
    $pageTitle = e($post['title']) . ' | ' . $companyName;
    $pageDescription = e($post['excerpt']);
    $pageExtraHeadTags = '<link rel="canonical" href="/blog-post.php?slug=' . e($slug) . '">';
}

require PROJECT_ROOT . '/includes/header.php';
?>
<main id="main-content">
    <?php if ($post === null): ?>
        <section class="section-pad">
            <div class="container">
                <div class="section-heading reveal">
                    <div>
                        <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Article Not Found</p>
                        <h2>This article isn&rsquo;t available.</h2>
                    </div>
                </div>
                <p>The article you&rsquo;re looking for may have been removed or is not currently published.</p>
                <a class="button button--primary" href="/blog.php">Explore Insights <span aria-hidden="true">→</span></a>
            </div>
        </section>
    <?php else: ?>
        <section class="hero reveal" style="background:var(--color-concrete);color:var(--color-ink-deep);padding-block:80px;">
            <div class="container hero__inner">
                <p class="eyebrow eyebrow--dark reveal reveal-delay-1"><span class="eyebrow__line"></span> <?= e($post['category_name'] ?? 'Construction Insights') ?></p>
                <h1 class="reveal reveal-delay-2"><?= e($post['title']) ?></h1>
                <p class="hero__intro reveal reveal-delay-3"><?= e($post['excerpt']) ?></p>
                <span class="reveal reveal-delay-4" style="font-size:0.875rem;color:var(--color-text-muted);">
                    Published <?= (new DateTimeImmutable($post['published_at']))->format('d M Y') ?>
                </span>
            </div>
        </section>

        <section class="blog-article section-pad reveal reveal-delay-5">
            <div class="container">
                <div class="blog-article__content">
                    <?= nl2br(e($post['content'])) ?>
                </div>
            </div>
        </section>

        <section class="cta reveal reveal-delay-6">
            <div class="container cta__inner">
                <div class="cta__side">
                    <h2>Planning your next<br><span>construction project?</span></h2>
                    <p>Talk to ICON Construction Company about your next building, renovation or civil works project.</p>
                </div>
                <div class="cta__actions">
                    <a class="button button--primary" href="/quote.php">Request a Quote <span aria-hidden="true">↗</span></a>
                </div>
            </div>
        </section>
    <?php endif; ?>
</main>
<?php require PROJECT_ROOT . '/includes/footer.php'; ?>
