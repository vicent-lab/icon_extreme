<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

$companyName = company_setting('company_name');
$pageTitle = 'Construction Insights | ' . $companyName;
$pageDescription = 'Explore construction insights, project planning guides, and industry knowledge from ICON Construction Company.';
$pageExtraHeadTags = '<link rel="canonical" href="/blog.php">';

require PROJECT_ROOT . '/includes/header.php';
?>
<main id="main-content">

    <section class="hero reveal" style="background:var(--color-concrete);color:var(--color-ink-deep);padding-block:80px;">
        <div class="container hero__inner">
            <p class="eyebrow eyebrow--dark reveal reveal-delay-1"><span class="eyebrow__line"></span> <?= e($companyName) ?> Insights</p>
            <h1 class="reveal reveal-delay-2">Construction Insights</h1>
            <p class="hero__intro reveal reveal-delay-3">Professional construction knowledge for property owners, developers and project managers in Uganda.</p>
        </div>
    </section>

    <section class="insights section-pad">
        <div class="container">
            <div class="insights-grid">
                <?php
                $databaseReady = getenv('DB_HOST') !== false
                    && getenv('DB_NAME') !== false
                    && getenv('DB_USER') !== false
                    && getenv('DB_PASSWORD') !== false;

                if ($databaseReady) {
                    try {
                        $connection = db();
                        $statement = $connection->prepare(
                            'SELECT bp.title, bp.slug, bp.excerpt, bp.featured_image, bp.published_at,
                                    bc.name AS category_name
                            FROM blog_posts bp
                            LEFT JOIN blog_categories bc ON bp.category_id = bc.id
                            WHERE bp.status = :status
                            ORDER BY bp.published_at DESC'
                        );
                        $statement->execute(['status' => 'published']);
                        $blogPosts = $statement->fetchAll();
                    } catch (PDOException | RuntimeException $error) {
                        error_log('ICON blog page query failed: ' . $error->getMessage());
                        $blogPosts = [];
                    }
                } else {
                    $blogPosts = [];
                }

                if ($blogPosts !== []):
                    foreach ($blogPosts as $index => $post):
                        ?>
                        <article class="insight-card reveal reveal-delay-<?= ($index % 3) + 1 ?>">
                            <?php if (!empty($post['featured_image'])): ?>
                                <div class="insight-card__image">
                                    <img src="<?= e(asset(project_image_thumbnail_path((string) $post['featured_image']))) ?>" alt="<?= e($post['title']) ?>" loading="lazy" width="600" height="400">
                                </div>
                            <?php else: ?>
                                <div class="insight-card__image">
                                    <img src="<?= e(asset('images/site/process-planning.webp')) ?>" alt="<?= e($post['title']) ?>" loading="lazy" width="600" height="400">
                                </div>
                            <?php endif; ?>
                            <div style="padding: 1.5rem;">
                                <?php if (!empty($post['category_name'])): ?>
                                    <span class="insight-card__category"><?= e($post['category_name']) ?></span>
                                <?php endif; ?>
                                <h3><?= e($post['title']) ?></h3>
                                <p><?= e($post['excerpt']) ?></p>
                                <a class="button button--outline" href="/blog-post.php?slug=<?= e($post['slug']) ?>" style="padding:10px 20px;font-size:12px;">Read Article <span aria-hidden="true">→</span></a>
                            </div>
                        </article>
                        <?php
                    endforeach;
                else:
                    ?>
                    <div class="insights-empty reveal reveal-delay-2">
                        <p>Insights and articles will be shared here as they are published.</p>
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </section>

</main>
<?php require PROJECT_ROOT . '/includes/footer.php'; ?>
