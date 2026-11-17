<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

$companyName = company_setting('company_name');
$companyTagline = company_setting('company_tagline');
$companyDescription = company_setting('company_description');
$companyAddress = company_setting('company_address');
$companyServiceArea = company_setting('company_service_area');
$companyPhone = company_setting('company_phone');
$companyEmail = company_setting('company_email');
$companyPhoneHref = company_phone_href();
$companyWhatsappHref = company_whatsapp_href();
$vision = company_setting('vision');
$mission = company_setting('mission');
$aboutDescription = company_setting('about_description');
$coreValuesRaw = company_setting('core_values');

$coreValues = [];
if ($coreValuesRaw !== '') {
    foreach (explode(';', $coreValuesRaw) as $pair) {
        $parts = explode(':', $pair, 2);
        if (count($parts) === 2) {
            $coreValues[] = ['title' => trim($parts[0]), 'description' => trim($parts[1])];
        }
    }
}

$heroHeading = company_setting('company_hero_heading');
$heroSubheading = company_setting('company_hero_subheading');

$processSteps = company_process_steps();

$heroSlideCount = 4;
$heroSlides = [];
for ($i = 1; $i <= $heroSlideCount; $i++) {
    $heroSlides[] = [
        'src' => company_asset_href('company_hero_image_' . $i, 'images/hero/hero-' . $i . '.webp'),
        'alt' => company_setting('company_hero_image_' . $i . '_alt') ?: $companyName . ' construction hero image ' . $i,
    ];
}

$services = [];
$projects = [];
$testimonials = [];
$blogPosts = [];
$projectCount = null;
$serviceCount = null;
$databaseReady = getenv('DB_HOST') !== false
    && getenv('DB_NAME') !== false
    && getenv('DB_USER') !== false
    && getenv('DB_PASSWORD') !== false;

if ($databaseReady) {
    try {
        $connection = db();

        $serviceStatement = $connection->prepare(
            'SELECT id, name, slug, short_description, icon, image, display_order
            FROM services
            WHERE status = :status
            ORDER BY is_featured DESC, display_order ASC, name ASC
            LIMIT 6'
        );
        $serviceStatement->execute(['status' => 'active']);
        $services = $serviceStatement->fetchAll();

        $serviceCountStatement = $connection->prepare(
            'SELECT COUNT(*) FROM services WHERE status = :status'
        );
        $serviceCountStatement->execute(['status' => 'active']);
        $serviceCount = (int) $serviceCountStatement->fetchColumn();

        $projectStatement = $connection->prepare(
            'SELECT p.id, p.title, p.slug, p.location, p.project_type, p.status, p.description,
                COALESCE(NULLIF(p.featured_image, \'\'), (
                    SELECT pi.image_path FROM project_images pi
                    WHERE pi.project_id = p.id ORDER BY pi.display_order, pi.id LIMIT 1
                )) AS featured_image,
                p.is_featured
            FROM projects p
            WHERE p.is_published = :published
            ORDER BY p.is_featured DESC, p.display_order ASC, p.created_at DESC
            LIMIT 6'
        );
        $projectStatement->execute(['published' => 1]);
        $projects = $projectStatement->fetchAll();

        $projectCountStatement = $connection->prepare(
            'SELECT COUNT(*) FROM projects WHERE is_published = :published'
        );
        $projectCountStatement->execute(['published' => 1]);
        $projectCount = (int) $projectCountStatement->fetchColumn();

        $testimonials = get_public_testimonials(10);
            error_log("DEBUG_TESTIMONIALS: count=" . count($testimonials) . " ids=" . implode(",", array_column($testimonials, 'id')));
            echo "<!-- TESTIMONIALS: " . count($testimonials) . " -->";
            error_log("DBG: count=" . count($testimonials));
            error_log("DEBUG_TESTIMONIALS: count=" . count($testimonials) . " ids=" . implode(",", array_column($testimonials, 'id')));
            error_log("DEBUG_TESTIMONIALS: count=" . count($testimonials) . " ids=" . implode(",", array_column($testimonials, 'id')) . " data=" . json_encode(array_slice($testimonials, 0, 3)));
            echo "<!-- TESTIMONIALS_COUNT: " . count($testimonials) . " -->";

        $blogTableCheck = $connection->prepare(
            'SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = :table_name'
        );
        $blogTableCheck->execute(['table_name' => 'blog_posts']);

        if ((int) $blogTableCheck->fetchColumn() > 0) {
            $blogStatement = $connection->prepare(
                'SELECT bp.title, bp.slug, bp.excerpt, bp.featured_image, bp.published_at,
                        bc.name AS category_name
                FROM blog_posts bp
                LEFT JOIN blog_categories bc ON bp.category_id = bc.id
                WHERE bp.status = :status
                ORDER BY bp.published_at DESC
                LIMIT 3'
            );
            $blogStatement->execute(['status' => 'published']);
            $blogPosts = $blogStatement->fetchAll();
        }
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON homepage database query failed: ' . $error->getMessage());
    }
}

if ($services === [] && !$databaseReady) {
    $services = [
        [
            'id' => 1,
            'name' => 'Building Construction',
            'slug' => 'building-construction',
            'short_description' => 'End-to-end building construction with thoughtful planning, coordinated site work and careful finishes.',
            'icon' => 'building',
            'image' => 'images/site/service-building-construction.webp',
            'display_order' => 1,
        ],
        [
            'id' => 2,
            'name' => 'Residential Construction',
            'slug' => 'residential-construction',
            'short_description' => 'Thoughtfully planned homes shaped around your site, household needs and agreed project scope.',
            'icon' => 'home',
            'image' => 'images/site/service-residential.webp',
            'display_order' => 2,
        ],
        [
            'id' => 3,
            'name' => 'Commercial Construction',
            'slug' => 'commercial-construction',
            'short_description' => 'Functional commercial spaces planned to support the way your organisation works.',
            'icon' => 'commercial',
            'image' => 'images/site/service-commercial.webp',
            'display_order' => 3,
        ],
        [
            'id' => 4,
            'name' => 'Renovation & Remodeling',
            'slug' => 'renovation-remodeling',
            'short_description' => 'Give an existing property a considered new layout, improved function or refreshed finish.',
            'icon' => 'renovation',
            'image' => 'images/site/service-renovation.webp',
            'display_order' => 4,
        ],
        [
            'id' => 5,
            'name' => 'Civil Works & Infrastructure',
            'slug' => 'civil-works',
            'short_description' => 'Site drainage, concrete substructures and earthworks managed to sound engineering principles.',
            'icon' => 'civil',
            'image' => 'images/site/service-civil-works.webp',
            'display_order' => 5,
        ],
        [
            'id' => 6,
            'name' => 'Roofing & Structural Works',
            'slug' => 'roofing',
            'short_description' => 'Engineered timber and steel roof structures, covering installation and water management.',
            'icon' => 'roofing',
            'image' => 'images/site/service-roofing.webp',
            'display_order' => 6,
        ],
    ];
    $serviceCount = 12;
}

if ($projects === [] && !$databaseReady) {
    $projects = [
        [
            'id' => 1,
            'title' => 'Victoria Ridge Residential Estate',
            'slug' => 'demo-modern-residential-development',
            'location' => 'Kololo, Kampala',
            'project_type' => 'Residential Construction',
            'status' => 'completed',
            'description' => 'A premier multi-unit luxury residential development featuring reinforced concrete framing and custom joinery.',
            'featured_image' => 'images/site/completed-residential.webp',
            'is_featured' => 1,
        ],
        [
            'id' => 2,
            'title' => 'Northline Commercial Complex',
            'slug' => 'demo-commercial-office-building',
            'location' => 'Nakasero, Kampala',
            'project_type' => 'Commercial Construction',
            'status' => 'completed',
            'description' => 'State-of-the-art multi-storey commercial office facility built to modern structural engineering standards.',
            'featured_image' => 'images/site/completed-commercial.webp',
            'is_featured' => 1,
        ],
        [
            'id' => 3,
            'title' => 'Entebbe Logistics Warehousing Facility',
            'slug' => 'demo-apartment-development',
            'location' => 'Entebbe',
            'project_type' => 'Civil Works & Industrial',
            'status' => 'ongoing',
            'description' => 'Heavy-duty industrial warehouse with engineered slab design and extensive civil drainage network.',
            'featured_image' => 'images/site/service-civil-works.webp',
            'is_featured' => 1,
        ],
    ];
    $projectCount = 6;
}

$contactHref = '/quote.php';

require PROJECT_ROOT . '/includes/header.php';
?>
<main id="main-content">

    <!-- ============================================
         1. HERO SECTION
         ============================================ -->
    <section class="hero hero--slider reveal" id="top" aria-label="<?= e($companyName) ?> hero" style="min-height: 85vh;">
        <div class="hero__slides" aria-hidden="true">
            <?php foreach ($heroSlides as $index => $slide): ?>
                <img
                    class="hero__slide<?= $index === 0 ? ' is-active' : '' ?>"
                    src="<?= e($slide['src']) ?>"
                    alt=""
                    <?= $index === 0 ? 'fetchpriority="high" loading="eager"' : 'loading="lazy"' ?>
                    decoding="async"
                    width="1920"
                    height="1200"
                    data-hero-slide="<?= $index ?>">
            <?php endforeach; ?>
        </div>
        <div class="hero__shade" aria-hidden="true"></div>
        <div class="container hero__inner">
            <div class="hero__content reveal reveal-delay-1">
                <span class="hero__eyebrow reveal reveal-delay-2"><?= e($companyName) ?></span>
                <h1 class="reveal reveal-delay-3"><?= e($heroHeading) ?></h1>
                <p class="hero__intro reveal reveal-delay-4"><?= e($heroSubheading) ?></p>
                <div class="hero__actions reveal reveal-delay-5">
                    <a class="button button--primary" href="<?= e($contactHref) ?>">Request a Quote <span aria-hidden="true">↗</span></a>
                    <a class="button button--outline" href="/projects.php">Explore Our Projects <span aria-hidden="true">→</span></a>
                </div>
            </div>
            <div class="hero__badge reveal reveal-delay-6">
                <span class="hero__badge-mark" aria-hidden="true">IC</span>
                <span><strong>Quality. Safety. Integrity.</strong><br>Built to last.</span>
            </div>
        </div>
        <div class="hero__indicators" role="tablist" aria-label="Hero background slides">
            <?php foreach ($heroSlides as $index => $slide): ?>
                <button
                    class="hero__indicator<?= $index === 0 ? ' is-active' : '' ?>"
                    type="button"
                    role="tab"
                    aria-selected="<?= $index === 0 ? 'true' : 'false' ?>"
                    aria-label="Show hero image <?= $index + 1 ?> of <?= count($heroSlides) ?>: <?= e($slide['alt']) ?>"
                    tabindex="<?= $index === 0 ? '0' : '-1' ?>"
                    data-hero-indicator="<?= $index ?>">
                    <span class="hero__indicator-dot" aria-hidden="true"></span>
                </button>
            <?php endforeach; ?>
        </div>
        <span class="visually-hidden" aria-live="polite" data-hero-status>Showing hero image 1 of <?= count($heroSlides) ?></span>
        <a class="hero__scroll reveal reveal-delay-7" href="#who-we-are"><span>Scroll to explore</span><span aria-hidden="true">↓</span></a>
    </section>

    <!-- ============================================
         2. WHO WE ARE
         ============================================ -->
    <section class="who-we-are section-pad" id="who-we-are">
        <div class="container who-we-are__grid">
            <div class="who-we-are__visual reveal reveal-delay-1">
                <div class="image-wrap reveal reveal-delay-2">
                    <img src="<?= e(asset('images/site/site-construction-workers.webp')) ?>" alt="ICON Construction team coordinating work on site" loading="lazy" width="1200" height="800">
                </div>
                <span class="who-we-are__badge reveal reveal-delay-3"><span>01</span> Every build begins with purpose</span>
            </div>
            <div class="who-we-are__copy reveal reveal-delay-4">
                <div class="gold-line"></div>
                <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Who we are</p>
                <h2>Building the spaces where<br><span>Uganda's future takes shape.</span></h2>
                <p><?= e($aboutDescription ?: $companyDescription) ?></p>
                <ul class="who-we-are__highlights">
                    <li><span class="highlight-mark" aria-hidden="true">✓</span> Quality workmanship</li>
                    <li><span class="highlight-mark" aria-hidden="true">✓</span> Professional project management</li>
                    <li><span class="highlight-mark" aria-hidden="true">✓</span> Safety-first approach</li>
                    <li><span class="highlight-mark" aria-hidden="true">✓</span> Reliability you can trust</li>
                </ul>
                <a class="button button--primary" href="/about.php">Discover ICON <span aria-hidden="true">→</span></a>
            </div>
        </div>
    </section>

    <!-- ============================================
         3. VISION & MISSION
         ============================================ -->
    <section class="vision-mission section-pad" id="vision-mission">
        <div class="container vision-mission__wrap">
            <div class="vision-mission__header reveal reveal-delay-1">
                <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Our direction</p>
                <h2>Vision &amp;<br><span>Mission.</span></h2>
            </div>
            <div class="vision-mission__grid">
                <article class="vision-card reveal reveal-delay-2">
                    <span class="vision-card__icon" aria-hidden="true">↗</span>
                    <span class="vision-card__label">VISION</span>
                    <h3>To become a trusted<br><span>respected builder.</span></h3>
                    <p><?= e($vision ?: 'To become a trusted and respected construction company known for delivering quality, sustainable and innovative projects that contribute to the development of Uganda and the wider region.') ?></p>
                </article>
                <article class="mission-card reveal reveal-delay-3">
                    <span class="mission-card__icon" aria-hidden="true">◆</span>
                    <span class="mission-card__label">MISSION</span>
                    <h3>To deliver reliable<br><span>construction solutions.</span></h3>
                    <p><?= e($mission ?: 'To deliver reliable construction solutions through quality workmanship, professional project management, safety, innovation and strong relationships with our clients and partners.') ?></p>
                </article>
            </div>
        </div>
    </section>

    <!-- ============================================
         4. CORE VALUES
         ============================================ -->
    <section class="core-values section-pad" id="core-values">
        <div class="container">
            <div class="section-heading reveal reveal-delay-1">
                <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> What we stand for</p>
                <h2>Core values<br><span>we live by.</span></h2>
            </div>
            <div class="values-grid">
                <?php foreach ($coreValues as $index => $value): ?>
                    <article class="value-card reveal reveal-delay-<?= ($index % 3) + 1 ?>">
                        <span class="value-card__number"><?= e(sprintf('%02d', $index + 1)) ?></span>
                        <h3><?= e($value['title']) ?></h3>
                        <p><?= e($value['description']) ?></p>
                    </article>
                <?php endforeach; ?>
            </div>
        </div>
    </section>

    <!-- ============================================
         5. WHAT WE BUILD / SERVICES
         ============================================ -->
    <section class="services section-pad" id="services">
        <div class="container">
            <div class="section-heading reveal reveal-delay-1">
                <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> What we do</p>
                <h2>What We Build<br><span>for you.</span></h2>
            </div>
            <p class="services-intro reveal reveal-delay-2">Professional construction solutions for residential, commercial and infrastructure projects across Uganda.</p>
            <?php if ($services !== []): ?>
            <div class="service-grid">
                <?php foreach ($services as $index => $service): ?>
                    <?php $serviceImage = !empty($service['image']) ? asset(project_image_thumbnail_path((string) $service['image'])) : asset('images/site/service-building-construction.webp'); ?>
                    <article class="premium-card service-card reveal reveal-delay-<?= ($index % 3) + 1 ?>">
                        <div class="image-wrap">
                            <img src="<?= e($serviceImage) ?>" alt="<?= e($service['name']) ?>" loading="lazy" width="600" height="400">
                        </div>
                        <div style="padding: 1.75rem;">
                            <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:1rem;">
                                <span class="service-card__number"><?= e(sprintf('%02d', (int) $service['display_order'])) ?></span>
                                <span class="service-card__icon" style="display:grid;width:44px;height:44px;place-items:center;border:1px solid rgba(201,162,39,.5);border-radius:50%;color:var(--color-gold-dark);font-size:20px;"><?= service_icon_svg((string) $service['icon']) ?></span>
                            </div>
                            <h3><?= e($service['name']) ?></h3>
                            <p><?= e($service['short_description']) ?></p>
                            <a class="button button--outline" href="/service.php?slug=<?= e($service['slug']) ?>" style="padding:12px 24px;font-size:12px;">Learn More <span aria-hidden="true">→</span></a>
                        </div>
                    </article>
                <?php endforeach; ?>
            </div>
            <a class="button button--outline services__all-link reveal reveal-delay-2" href="/services.php" style="margin-top:16px;">View All Services <span aria-hidden="true">→</span></a>
            <?php else: ?>
                <div class="services-empty reveal reveal-delay-2">
                    <div class="services-empty__icon" aria-hidden="true">⌂</span>
                    <div>
                        <h3>Our service details are being prepared.</h3>
                        <p>Service information will appear here as it is added to our portfolio.</p>
                    </div>
                    <a class="text-link text-link--light" href="/services.php">Explore portfolio <span aria-hidden="true">→</span></a>
                </div>
            <?php endif; ?>
        </div>
    </section>

    <!-- ============================================
         6. FEATURED PROJECTS
         ============================================ -->
    <section class="projects section-pad" id="projects">
        <div class="container">
            <div class="section-heading reveal reveal-delay-1">
                <p class="eyebrow"><span class="eyebrow__line"></span> Selected work</p>
                <h2>Featured Projects<br><span>that speak for us.</span></h2>
            </div>
            <p class="projects-intro reveal reveal-delay-2">Explore selected projects and discover the quality behind every structure.</p>
            <?php if ($projects !== []): ?>
                <div class="project-grid">
                    <?php foreach ($projects as $index => $project): ?>
                        <?php
                        $projectImagePath = !empty($project['featured_image'])
                            ? (string) $project['featured_image']
                            : ($index % 2 === 0 ? 'images/site/site-construction-workers.webp' : 'images/site/site-equipment.webp');
                        $projectImage = !empty($project['featured_image'])
                            ? asset(project_image_thumbnail_path($projectImagePath))
                            : asset($projectImagePath);
                        $isLarge = $index % 3 === 0;
                        ?>
                        <a class="project-card premium-card reveal reveal-delay-<?= ($index % 3) + 1 ?>" href="/project-details.php?id=<?= e((string) $project['id']) ?>">
                            <div class="project-card__image" style="height: <?= $isLarge ? '520px' : '340px' ?>;">
                                <img src="<?= e($projectImage) ?>" alt="<?= e($project['title'] . ' — ' . $project['project_type']) ?>" loading="lazy" width="<?= $isLarge ? '900' : '640' ?>" height="<?= $isLarge ? '600' : '420' ?>">
                                <span class="project-card__arrow" aria-hidden="true">↗</span>
                            </div>
                            <div class="project-card__details" style="padding: 1.75rem;">
                                <div class="project-card__eyebrow">
                                    <span><?= e($project['project_type']) ?></span>
                                    <span class="project-status project-status--<?= e($project['status']) ?>"><?= e(ucfirst((string) $project['status'])) ?></span>
                                </div>
                                <h3><?= e($project['title']) ?></h3>
                                <p><?= e($project['location'] ?? 'Uganda') ?></p>
                                <span class="project-card__view">View Project <span aria-hidden="true">→</span></span>
                            </div>
                        </a>
                    <?php endforeach; ?>
                </div>
                <a class="button button--outline project-more reveal reveal-delay-2" href="/projects.php" style="margin-top:16px;">View All Projects <span aria-hidden="true">→</span></a>
            <?php else: ?>
                <div class="projects-empty reveal reveal-delay-2">
                    <span class="projects-empty__icon" aria-hidden="true">⌂</span>
                    <div>
                        <h3>Our project portfolio is taking shape.</h3>
                        <p>Featured projects will appear here as they are added to the company portfolio.</p>
                    </div>
                    <a class="text-link text-link--light" href="/projects.php">Explore portfolio <span aria-hidden="true">→</span></a>
                </div>
            <?php endif; ?>
        </div>
    </section>

    <!-- ============================================
         6. FEATURED PROJECTS
         ============================================ -->
    <section class="projects section-pad" id="projects">
        <div class="container">
            <div class="section-heading reveal reveal-delay-1">
                <p class="eyebrow"><span class="eyebrow__line"></span> Selected work</p>
                <h2>Featured Projects<br><span>that speak for us.</span></h2>
            </div>
            <p class="projects-intro reveal reveal-delay-2">Explore selected projects and discover the quality behind every structure.</p>
            <?php if ($projects !== []): ?>
                <div class="project-grid">
                    <?php foreach ($projects as $index => $project): ?>
                        <?php
                        $projectImagePath = !empty($project['featured_image'])
                            ? (string) $project['featured_image']
                            : ($index % 2 === 0 ? 'images/site/site-construction-workers.webp' : 'images/site/site-equipment.webp');
                        $projectImage = !empty($project['featured_image'])
                            ? asset(project_image_thumbnail_path($projectImagePath))
                            : asset($projectImagePath);
                        $isLarge = $index % 3 === 0;
                        ?>
                        <a class="project-card premium-card reveal reveal-delay-<?= ($index % 3) + 1 ?>" href="/project-details.php?id=<?= e((string) $project['id']) ?>">
                            <div class="project-card__image" style="height: <?= $isLarge ? '520px' : '340px' ?>;">
                                <img src="<?= e($projectImage) ?>" alt="<?= e($project['title'] . ' — ' . $project['project_type']) ?>" loading="lazy" width="<?= $isLarge ? '900' : '640' ?>" height="<?= $isLarge ? '600' : '420' ?>">
                                <span class="project-card__arrow" aria-hidden="true">↗</span>
                            </div>
                            <div class="project-card__details" style="padding: 1.75rem;">
                                <div class="project-card__eyebrow">
                                    <span><?= e($project['project_type']) ?></span>
                                    <span class="project-status project-status--<?= e($project['status']) ?>"><?= e(ucfirst((string) $project['status'])) ?></span>
                                </div>
                                <h3><?= e($project['title']) ?></h3>
                                <p><?= e($project['location'] ?? 'Uganda') ?></p>
                                <span class="project-card__view">View Project <span aria-hidden="true">→</span></span>
                            </div>
                        </a>
                    <?php endforeach; ?>
                </div>
                <a class="button button--outline project-more reveal reveal-delay-2" href="/projects.php" style="margin-top:16px;">View All Projects <span aria-hidden="true">→</span></a>
            <?php else: ?>
                <div class="projects-empty reveal reveal-delay-2">
                    <span class="projects-empty__icon" aria-hidden="true">⌂</span>
                    <div>
                        <h3>Our project portfolio is taking shape.</h3>
                        <p>Featured projects will appear here as they are added to the company portfolio.</p>
                    </div>
                    <a class="text-link text-link--light" href="/projects.php">Explore portfolio <span aria-hidden="true">→</span></a>
                </div>
            <?php endif; ?>
        </div>
    </section>

    <!-- ============================================
         7. TESTIMONIALS / CLIENT REVIEWS
         ============================================ -->
    <section class="testimonials section-pad" id="testimonials" aria-labelledby="testimonials-heading">
        <div class="container">
            <div class="testimonials__header reveal reveal-delay-1">
                <div class="section-heading">
                    <p class="eyebrow eyebrow--gold"><span class="eyebrow__line"></span> What Our Clients Say</p>
                    <h2 id="testimonials-heading">Trusted by the People &amp; Organizations<br><span>We Have Worked With.</span></h2>
                    <p class="testimonials-header__subtext">Authentic experiences and genuine project partnerships delivered with quality, safety, and lasting engineering value.</p>
                </div>
                <?php if (count($testimonials) > 1): ?>
                <div class="testimonials-nav" aria-label="Testimonial navigation">
                    <button type="button" class="testimonials-nav__btn testimonials-nav__btn--prev" aria-label="Previous testimonial" data-testimonial-prev>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="15 18 9 12 15 6"></polyline></svg>
                    </button>
                    <button type="button" class="testimonials-nav__btn testimonials-nav__btn--next" aria-label="Next testimonial" data-testimonial-next>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="9 18 15 12 9 6"></polyline></svg>
                    </button>
                </div>
                <?php endif; ?>
            </div>

            <?php if ($testimonials !== []): ?>
            <div class="testimonials-carousel" data-testimonial-carousel role="region" aria-roledescription="carousel" aria-label="Client testimonials">
                <div class="testimonials-carousel__viewport">
                    <div class="testimonials-carousel__track" data-testimonial-track>
                        <?php foreach ($testimonials as $index => $testimonial): ?>
                            <?php
                            $ratingVal = (!empty($testimonial['rating']) && (int) $testimonial['rating'] >= 1 && (int) $testimonial['rating'] <= 5)
                                ? (int) $testimonial['rating']
                                : null;
                            $hasProjectLink = !empty($testimonial['linked_project_id']);
                            $projectDisplay = !empty($testimonial['linked_project_title'])
                                ? $testimonial['linked_project_title']
                                : ($testimonial['project_name'] ?? '');
                            ?>
                            <article class="testimonial-slide<?= $index === 0 ? ' is-active' : '' ?>"
                                     role="group"
                                     aria-roledescription="slide"
                                     aria-label="Testimonial <?= $index + 1 ?> of <?= count($testimonials) ?>"
                                     data-testimonial-slide="<?= $index ?>"
                                     itemscope itemtype="https://schema.org/Review">
                                <div class="testimonial-card">
                                    <div class="testimonial-card__watermark" aria-hidden="true">
                                        <svg width="120" height="120" viewBox="0 0 24 24" fill="currentColor">
                                            <path d="M14.017 21v-7.391c0-5.704 3.731-9.57 8.983-10.609l.995 2.151c-2.432.917-3.995 3.638-3.995 5.849h4v10h-9.983zm-14.017 0v-7.391c0-5.704 3.748-9.57 9-10.609l.996 2.151c-2.433.917-3.996 3.638-3.996 5.849h3.983v10h-9.983z"/>
                                        </svg>
                                    </div>

                                    <div class="testimonial-card__top">
                                        <div class="testimonial-badge-verified">
                                            <span class="pulse-dot"></span>
                                            <span>Verified Client Review</span>
                                        </div>
                                        <?php if ($ratingVal !== null): ?>
                                            <div class="testimonial-rating-pill" aria-label="Rating: <?= $ratingVal ?> out of 5 stars" itemprop="reviewRating" itemscope itemtype="https://schema.org/Rating">
                                                <meta itemprop="ratingValue" content="<?= $ratingVal ?>">
                                                <meta itemprop="bestRating" content="5">
                                                <meta itemprop="worstRating" content="1">
                                                <span class="star-icon" aria-hidden="true">★</span>
                                                <span class="rating-num"><?= number_format($ratingVal, 1) ?></span>
                                                <span class="rating-scale">/ 5.0</span>
                                            </div>
                                        <?php endif; ?>
                                    </div>

                                    <blockquote class="testimonial-card__body" itemprop="reviewBody">
                                        <p>“<?= nl2br(e($testimonial['quote'])) ?>”</p>
                                    </blockquote>

                                    <footer class="testimonial-card__footer">
                                        <div class="testimonial-card__client">
                                            <?php if (!empty($testimonial['client_photo'])): ?>
                                                <div class="testimonial-card__photo-wrap">
                                                    <img src="<?= e(asset($testimonial['client_photo'])) ?>"
                                                         alt="<?= e($testimonial['client_name']) ?>"
                                                         class="testimonial-client-photo"
                                                         loading="lazy"
                                                         width="64"
                                                         height="64">
                                                </div>
                                            <?php else: ?>
                                                <div class="testimonial-client-avatar" aria-hidden="true">
                                                    <?= strtoupper(substr(trim((string) $testimonial['client_name']), 0, 1)) ?>
                                                </div>
                                            <?php endif; ?>

                                            <div class="testimonial-card__client-meta">
                                                <h3 class="testimonial-card__client-name" itemprop="author" itemscope itemtype="https://schema.org/Person">
                                                    <span itemprop="name"><?= e($testimonial['client_name']) ?></span>
                                                    <span class="verified-check" title="Verified client" aria-hidden="true">✓</span>
                                                </h3>

                                                <?php if (!empty($testimonial['client_role']) || !empty($testimonial['company'])): ?>
                                                    <p class="testimonial-card__client-role">
                                                        <?php if (!empty($testimonial['client_role'])): ?>
                                                            <span class="client-role-text"><?= e($testimonial['client_role']) ?></span>
                                                        <?php endif; ?>
                                                        <?php if (!empty($testimonial['client_role']) && !empty($testimonial['company'])): ?>
                                                            <span class="testimonial-card__divider" aria-hidden="true">/</span>
                                                        <?php endif; ?>
                                                        <?php if (!empty($testimonial['company'])): ?>
                                                            <strong class="testimonial-card__client-company"><?= e($testimonial['company']) ?></strong>
                                                        <?php endif; ?>
                                                    </p>
                                                <?php endif; ?>

                                                <?php if (!empty($projectDisplay)): ?>
                                                    <div class="testimonial-card__project">
                                                        <span class="testimonial-card__project-tag">Project:</span>
                                                        <?php if ($hasProjectLink): ?>
                                                            <a href="/project-details.php?id=<?= (int) $testimonial['linked_project_id'] ?>" class="testimonial-card__project-link" title="View project details for <?= e($projectDisplay) ?>">
                                                                <?= e($projectDisplay) ?> <span class="arrow-glyph" aria-hidden="true">↗</span>
                                                            </a>
                                                        <?php else: ?>
                                                            <span class="testimonial-card__project-name"><?= e($projectDisplay) ?></span>
                                                        <?php endif; ?>
                                                    </div>
                                                <?php endif; ?>
                                            </div>
                                        </div>

                                        <?php if (!empty($testimonial['company_logo'])): ?>
                                            <div class="testimonial-card__logo-wrap" title="<?= e($testimonial['company'] ?? 'Client organization') ?>">
                                                <img src="<?= e(asset($testimonial['company_logo'])) ?>"
                                                     alt="<?= e($testimonial['company'] ?? 'Client') ?> logo"
                                                     class="testimonial-company-logo"
                                                     loading="lazy"
                                                     height="38">
                                            </div>
                                        <?php endif; ?>
                                    </footer>
                                </div>
                            </article>
                        <?php endforeach; ?>
                    </div>
                </div>

                <?php if (count($testimonials) > 1): ?>
                <div class="testimonials-pagination" role="tablist" aria-label="Testimonial slider pagination">
                    <?php foreach ($testimonials as $index => $testimonial): ?>
                        <button type="button"
                                role="tab"
                                class="testimonials-pagination__dot<?= $index === 0 ? ' is-active' : '' ?>"
                                aria-selected="<?= $index === 0 ? 'true' : 'false' ?>"
                                aria-label="Go to testimonial <?= $index + 1 ?>"
                                data-testimonial-dot="<?= $index ?>"
                                tabindex="<?= $index === 0 ? '0' : '-1' ?>"></button>
                    <?php endforeach; ?>
                </div>
                <?php endif; ?>
            </div>
            <?php else: ?>
            <!-- =======================================================
                 EXECUTIVE CLIENT TRUST & EXPERIENCES SHOWCASE (OPTION B)
                 ======================================================= -->
            <div class="testimonials-trust-showcase reveal reveal-delay-2">
                <div class="trust-showcase__header">
                    <span class="trust-showcase__badge">✦ ICON Quality &amp; Trust Assurance</span>
                    <h3 class="trust-showcase__title">Committed to Engineering Excellence in Every Build</h3>
                    <p class="testimonials-empty__message">Client experiences will be featured here as ICON Construction’s project portfolio grows.</p>
                </div>

                <div class="trust-showcase__quote-card">
                    <div class="trust-showcase__quote-mark" aria-hidden="true">“</div>
                    <blockquote class="trust-showcase__quote-text">
                        Every review and milestone featured by ICON Construction reflects an authentic, contracted project partnership. In accordance with our professional code, we never deploy fictional testimonials or unverified claims.
                    </blockquote>
                    <div class="trust-showcase__quote-meta">
                        <strong>ICON Construction Quality Council</strong>
                        <span>Uganda Building &amp; Civil Engineering Standards</span>
                    </div>
                </div>

                <div class="trust-showcase__pillars">
                    <div class="trust-pillar">
                        <div class="trust-pillar__icon" aria-hidden="true">
                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
                        </div>
                        <div class="trust-pillar__content">
                            <h4>Direct Accountability</h4>
                            <p>All reviews are authenticated with verified property developers, institutional leaders, and homeowners.</p>
                        </div>
                    </div>

                    <div class="trust-pillar">
                        <div class="trust-pillar__icon" aria-hidden="true">
                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path></svg>
                        </div>
                        <div class="trust-pillar__content">
                            <h4>Connected Portfolio</h4>
                            <p>Feedback is linked directly to documented site progress, materials tracking, and completed works.</p>
                        </div>
                    </div>

                    <div class="trust-pillar">
                        <div class="trust-pillar__icon" aria-hidden="true">
                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 14 14"></polyline></svg>
                        </div>
                        <div class="trust-pillar__content">
                            <h4>Milestone Transparency</h4>
                            <p>Client milestones are formally signed off against agreed drawings, structural codes, and budgets.</p>
                        </div>
                    </div>
                </div>

                <div class="trust-showcase__actions">
                    <a href="/projects.php" class="btn btn--primary">Explore Completed Projects <span aria-hidden="true">↗</span></a>
                    <a href="/quote.php" class="btn btn--outline">Request Project Consultation</a>
                </div>
            </div>
            <?php endif; ?>
        </div>
    </section>

    <!-- ============================================
         7. CONSTRUCTION JOURNEY
         ============================================ -->
        <div class="container">
            <div class="section-heading reveal reveal-delay-1">
                <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Construction journey</p>
                <h2>From idea to<br><span>completion.</span></h2>
            </div>
            <div class="journey-timeline">
                <?php foreach ($processSteps as $index => $step): ?>
                    <div class="journey-step reveal reveal-delay-<?= ($index % 3) + 1 ?>">
                        <div class="journey-badge"><?= e(sprintf('%02d', $index + 1)) ?></div>
                        <div class="journey-line"></div>
                        <div class="journey-content">
                            <h3><?= e($step['title']) ?></h3>
                            <p><?= e($step['description']) ?></p>
                        </div>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>
    </section>

    <!-- ============================================
         8. SAFETY & QUALITY
         ============================================ -->
    <section class="safety-quality section-pad" id="safety-quality">
        <div class="container safety-quality__wrap">
            <div class="safety-quality__media reveal reveal-delay-1">
                <img src="<?= e(asset('images/site/safety-ppe.webp')) ?>" alt="Construction workers wearing PPE safety gear on site" loading="lazy" width="1200" height="800">
            </div>
            <div class="safety-quality__copy reveal reveal-delay-2">
                <div class="gold-line"></div>
                <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Built safely.</p>
                <h2>Built to last.<br><span>Every time.</span></h2>
                <ul class="safety-list">
                    <li><span class="safety-mark" aria-hidden="true">✓</span> Site safety and PPE on every project</li>
                    <li><span class="safety-mark" aria-hidden="true">✓</span> Quality control at every stage</li>
                    <li><span class="safety-mark" aria-hidden="true">✓</span> Professional site supervision</li>
                    <li><span class="safety-mark" aria-hidden="true">✓</span> Proper construction practices</li>
                    <li><span class="safety-mark" aria-hidden="true">✓</span> Attention to every detail</li>
                </ul>
            </div>
        </div>
    </section>

    <!-- ============================================
         9. CONSTRUCTION INSIGHTS
         ============================================ -->
    <section class="insights section-pad" id="insights">
        <div class="container">
            <div class="section-heading reveal reveal-delay-1">
                <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Construction insights</p>
                <h2>Expert knowledge<br><span>for your build.</span></h2>
            </div>
            <div class="insights-grid">
                <?php if ($blogPosts !== []): ?>
                    <?php foreach ($blogPosts as $index => $post): ?>
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
                    <?php endforeach; ?>
                <?php else: ?>
                    <div class="insights-empty reveal reveal-delay-2">
                        <p>Insights and articles will be shared here as they are published.</p>
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </section>

    <!-- ============================================
         14. PROJECT CTA
         ============================================ -->
    <section class="project-cta" id="quote">
        <div class="container cta__inner reveal reveal-delay-1">
            <div class="cta__side">
                <h2>Have a project in<br><span>mind?</span></h2>
                <p>Let's turn your plans into a structure built to last.</p>
            </div>
            <div class="cta__actions">
                <a class="button button--primary" href="<?= e($contactHref) ?>">Request a Quote <span aria-hidden="true">↗</span></a>
                <a class="button button--outline" href="/contact.php">Talk to ICON <span aria-hidden="true">→</span></a>
            </div>
        </div>
    </section>

    <!-- ============================================
         15. CONTACT PREVIEW
         ============================================ -->
    <section class="contact-preview section-pad" id="contact">
        <div class="container contact-preview__grid">
            <div class="contact-preview__brand reveal reveal-delay-1">
                <div class="brand-block">
                    <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> ICON Construction Company</p>
                    <h2>Get in touch<br><span>with us.</span></h2>
                    <p><?= e($companyServiceArea) ?> — <?= e($companyTagline) ?></p>
                </div>
                <div class="contact-info">
                    <div class="contact-item">
                        <span class="contact-label">Location</span>
                        <strong><?= e($companyAddress) ?></strong>
                    </div>
                    <div class="contact-item">
                        <span class="contact-label">Phone</span>
                        <?php if ($companyPhoneHref !== ''): ?>
                            <a href="<?= e($companyPhoneHref) ?>"><?= e(company_phone_display()) ?></a>
                        <?php else: ?>
                            <strong>Being updated</strong>
                        <?php endif; ?>
                    </div>
                    <div class="contact-item">
                        <span class="contact-label">WhatsApp</span>
                        <?php if ($companyWhatsappHref !== ''): ?>
                            <a href="<?= e($companyWhatsappHref) ?>" target="_blank" rel="noopener noreferrer">Chat with us <span aria-hidden="true">↗</span></a>
                        <?php else: ?>
                            <strong>Being updated</strong>
                        <?php endif; ?>
                    </div>
                    <div class="contact-item">
                        <span class="contact-label">Email</span>
                        <?php if ($companyEmail !== ''): ?>
                            <a href="mailto:<?= e($companyEmail) ?>"><?= e($companyEmail) ?></a>
                        <?php else: ?>
                            <strong>Being updated</strong>
                        <?php endif; ?>
                    </div>
                    <?php if (company_setting('company_business_hours') !== ''): ?>
                    <div class="contact-item">
                        <span class="contact-label">Business hours</span>
                        <strong><?= nl2br(e(company_setting('company_business_hours'))) ?></strong>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
            <div class="contact-preview__form reveal reveal-delay-2">
                <h3>Send us a message</h3>
                <p class="contact-form-intro">Share your project details and our team will get back to you.</p>
                <a class="button button--primary" href="/contact.php">Open Contact Form <span aria-hidden="true">→</span></a>
            </div>
        </div>
    </section>

</main>
<?php require PROJECT_ROOT . '/includes/footer.php'; ?>
