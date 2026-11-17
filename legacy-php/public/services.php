<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

$companyName = company_setting('company_name');
$companyTagline = company_setting('company_tagline');
$companyDescription = company_setting('company_description');
$pageTitle = 'Services | ' . $companyName;
$pageDescription = 'Explore ' . $companyName . ' construction services, from residential and commercial construction to civil works and finishing.';
$pageExtraHeadTags = '<link rel="canonical" href="/services.php">';
$services = [];
$databaseReady = getenv('DB_HOST') !== false
    && getenv('DB_NAME') !== false
    && getenv('DB_USER') !== false
    && getenv('DB_PASSWORD') !== false;

if ($databaseReady) {
    try {
        $statement = db()->prepare(
            'SELECT name, slug, short_description, icon, image, display_order
            FROM services
            WHERE status = :status
            ORDER BY is_featured DESC, display_order ASC, name ASC'
        );
        $statement->execute(['status' => 'active']);
        $services = $statement->fetchAll();
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON services page database query failed: ' . $error->getMessage());
    }
}

if (!$databaseReady) {
    $services = [
        ['name' => 'Building Construction', 'slug' => 'building-construction', 'short_description' => 'Full-service building construction from foundation to finish, tailored to your residential or commercial needs.', 'icon' => 'building', 'image' => 'images/site/service-building-construction.webp', 'display_order' => 1],
        ['name' => 'Residential Construction', 'slug' => 'residential-construction', 'short_description' => 'Custom homes, renovations and extensions designed around your family and lifestyle.', 'icon' => 'home', 'image' => 'images/site/service-residential.webp', 'display_order' => 2],
        ['name' => 'Commercial Construction', 'slug' => 'commercial-construction', 'short_description' => 'Office buildings, retail spaces and commercial developments built for performance and durability.', 'icon' => 'building', 'image' => 'images/site/service-commercial.webp', 'display_order' => 3],
        ['name' => 'Civil Works', 'slug' => 'civil-works', 'short_description' => 'Infrastructure and civil engineering projects including drainage, earthworks and site preparation.', 'icon' => 'tools', 'image' => 'images/site/service-civil-works.webp', 'display_order' => 4],
        ['name' => 'Road Works', 'slug' => 'road-works', 'short_description' => 'Road construction, rehabilitation and maintenance for access roads and site infrastructure.', 'icon' => 'road', 'image' => 'images/site/service-road-civil.webp', 'display_order' => 5],
        ['name' => 'Roofing', 'slug' => 'roofing', 'short_description' => 'Professional roofing installation and repair for residential and commercial buildings.', 'icon' => 'shield', 'image' => 'images/site/service-roofing.webp', 'display_order' => 6],
    ];
}

require PROJECT_ROOT . '/includes/header.php';
?>
<main id="main-content">

    <section class="hero hero--slider reveal" id="top" aria-label="<?= e($companyName) ?> hero" style="min-height: 60vh;">
        <div class="hero__slides" aria-hidden="true">
            <img class="hero__slide is-active" src="<?= e(asset('images/site/service-building-construction.webp')) ?>" alt="Construction services building projects" loading="eager" width="1920" height="1200" decoding="async">
        </div>
        <div class="hero__shade" aria-hidden="true"></div>
        <div class="container hero__inner">
            <div class="hero__content reveal reveal-delay-1">
                <span class="hero__eyebrow reveal reveal-delay-2"><?= e($companyName) ?></span>
                <h1 class="reveal reveal-delay-3">Construction Services</h1>
                <p class="hero__intro reveal reveal-delay-4"><?= e($companyDescription) ?></p>
                <div class="hero__actions reveal reveal-delay-5">
                    <a class="button button--primary" href="/quote.php">Request a Quote <span aria-hidden="true">↗</span></a>
                    <a class="button button--outline" href="/contact.php">Talk to ICON <span aria-hidden="true">→</span></a>
                </div>
            </div>
        </div>
    </section>

    <section class="services section-pad">
        <div class="container">
            <div class="section-heading reveal reveal-delay-1">
                <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> What we do</p>
                <h2>What We Build<br><span>for you.</span></h2>
            </div>
            <p class="services-intro reveal reveal-delay-2">Professional construction solutions for residential, commercial and infrastructure projects across Uganda.</p>
            <div class="service-grid">
                <?php if ($services !== []): ?>
                    <?php foreach ($services as $index => $service): ?>
                        <?php $imagePath = !empty($service['image']) ? (string) $service['image'] : 'images/site/service-building-construction.webp'; ?>
                        <article class="premium-card service-card reveal reveal-delay-<?= ($index % 3) + 1 ?>">
                            <div class="image-wrap">
                                <img src="<?= e(asset($imagePath)) ?>" alt="<?= e($service['name']) ?>" loading="lazy" width="600" height="400">
                            </div>
                            <div style="padding: 1.75rem;">
                                <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:1rem;">
                                    <span class="service-card__number"><?= e(sprintf('%02d', $service['display_order'])) ?></span>
                                    <span class="service-card__icon" style="display:grid;width:44px;height:44px;place-items:center;border:1px solid rgba(201,162,39,.5);border-radius:50%;color:var(--color-gold-dark);font-size:20px;"><?= service_icon_svg((string) $service['icon']) ?></span>
                                </div>
                                <h3><?= e($service['name']) ?></h3>
                                <p><?= e($service['short_description']) ?></p>
                                <a class="button button--outline" href="/service.php?slug=<?= e($service['slug']) ?>" style="padding:12px 24px;font-size:12px;">Learn More <span aria-hidden="true">→</span></a>
                            </div>
                        </article>
                    <?php endforeach; ?>
                <?php else: ?>
                    <p class="services-empty">Services will appear here when they are published from the dashboard.</p>
                <?php endif; ?>
            </div>
            <a class="button button--outline services__all-link reveal reveal-delay-2" href="/quote.php" style="margin-top:16px;">Discuss Your Project <span aria-hidden="true">→</span></a>
        </div>
    </section>

</main>
<?php require PROJECT_ROOT . '/includes/footer.php'; ?>
