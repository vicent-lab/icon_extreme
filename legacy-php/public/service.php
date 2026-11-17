<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

$companyName = company_setting('company_name');
$slug = filter_input(INPUT_GET, 'slug', FILTER_SANITIZE_SPECIAL_CHARS);

$service = null;
$databaseReady = getenv('DB_HOST') !== false
    && getenv('DB_NAME') !== false
    && getenv('DB_USER') !== false
    && getenv('DB_PASSWORD') !== false;

if ($databaseReady && $slug !== false && $slug !== '') {
    try {
        $connection = db();
        $statement = $connection->prepare(
            'SELECT id, name, slug, short_description, full_description, icon, image, display_order
            FROM services
            WHERE slug = :slug AND status = :status
            LIMIT 1'
        );
        $statement->execute(['slug' => $slug, 'status' => 'active']);
        $service = $statement->fetch();
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON service page database query failed: ' . $error->getMessage());
    }
}

if ($service === null) {
    http_response_code(404);
    $pageTitle = 'Service Not Found | ' . $companyName;
    $pageDescription = 'The requested service is not available.';
} else {
    $pageTitle = e($service['name']) . ' | ' . $companyName;
    $pageDescription = e($service['short_description']);
    $pageExtraHeadTags = '<link rel="canonical" href="/service.php?slug=' . e($slug) . '">';
}

require PROJECT_ROOT . '/includes/header.php';
?>
<main id="main-content">
    <?php if ($service === null): ?>
        <section class="section-pad">
            <div class="container">
                <div class="section-heading reveal">
                    <div>
                        <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Service Not Found</p>
                        <h2>This service isn&rsquo;t available.</h3>
                    </div>
                </div>
                <p>The service you&rsquo;re looking for may have been removed or is not currently published.</p>
                <a class="button button--primary" href="/services.php">Explore Our Services <span aria-hidden="true">→</span></a>
            </div>
        </section>
    <?php else: ?>
        <section class="hero reveal" style="background:var(--color-concrete);color:var(--color-ink-deep);padding-block:80px;">
            <div class="container hero__inner">
                <p class="eyebrow eyebrow--dark reveal reveal-delay-1"><span class="eyebrow__line"></span> <?= e($companyName) ?> Services</p>
                <h1 class="reveal reveal-delay-2"><?= e($service['name']) ?></h1>
                <p class="hero__intro reveal reveal-delay-3"><?= e($service['short_description']) ?></p>
            </div>
        </section>

        <section class="section-pad reveal reveal-delay-4">
            <div class="container">
                <div class="service-detail__grid">
                    <div class="service-detail__content">
                        <div class="service-detail__image-wrap image-wrap" style="height:320px;">
                            <img src="<?= e(asset(project_image_thumbnail_path((string) $service['image']))) ?>" alt="<?= e($service['name']) ?>" loading="lazy" width="1200" height="800">
                        </div>
                        <div class="service-detail__body">
                            <h2>About This Service</h2>
                            <p><?= nl2br(e($service['full_description'])) ?></p>
                            <a class="button button--primary" href="/quote.php">Request a Quote <span aria-hidden="true">→</span></a>
                        </div>
                    </div>
                    <div class="service-detail__sidebar">
                        <div class="service-detail__card">
                            <h3>Service Details</h3>
                            <ul class="service-detail__list">
                                <li><strong>Service:</strong> <?= e($service['name']) ?></li>
                                <li><strong>Status:</strong> Active</li>
                                <li><strong>Service Area:</strong> <?= e(company_setting('company_service_area')) ?></li>
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    <?php endif; ?>
</main>
<?php require PROJECT_ROOT . '/includes/footer.php'; ?>
