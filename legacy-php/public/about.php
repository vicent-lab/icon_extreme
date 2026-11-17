<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

$companyName = company_setting('company_name');
$pageTitle = 'About ' . $companyName;
$pageDescription = company_setting('company_description');
$processSteps = company_process_steps();
$aboutImages = [
    ['images/site/site-construction-workers.webp', 'Construction workers coordinating tasks on a building site', 'Construction workers'],
    ['images/site/process-planning.webp', 'Building plans reviewed during project planning', 'Planning and design'],
    ['images/site/site-engineers-supervision.webp', 'Engineers and supervisors reviewing progress on site', 'Engineers and supervision'],
    ['images/site/site-equipment.webp', 'Construction equipment and materials at an active work site', 'Equipment on site'],
    ['images/site/completed-commercial.webp', 'Completed commercial building viewed from street level', 'Completed buildings'],
    ['images/site/safety-ppe.webp', 'Construction team wearing helmets and protective equipment', 'Safety in practice'],
];
$teamMembers = [];
$databaseReady = getenv('DB_HOST') !== false
    && getenv('DB_NAME') !== false
    && getenv('DB_USER') !== false
    && getenv('DB_PASSWORD') !== false;

if ($databaseReady) {
    try {
        $statement = db()->prepare(
            'SELECT name, job_title, bio, image
            FROM team_members
            WHERE status = :status
            ORDER BY display_order ASC, name ASC'
        );
        $statement->execute(['status' => 'active']);
        $teamMembers = $statement->fetchAll();
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON about page team query failed: ' . $error->getMessage());
    }
}

require PROJECT_ROOT . '/includes/header.php';
?>
<main id="main-content">
    <section class="about-hero">
        <div class="about-hero__image" aria-hidden="true" style="background-image:url('<?= e(company_asset_href('company_hero_image')) ?>')"></div>
        <div class="about-hero__shade" aria-hidden="true"></div>
        <div class="container about-hero__inner">
            <p class="eyebrow"><span class="eyebrow__line"></span> About <?= e($companyName) ?></p>
            <h1>Building better,<br><span>together.</span></h1>
            <p><?= e(company_setting('company_tagline')) ?></p>
        </div>
    </section>

    <section class="about-banner section-pad" aria-label="Construction site banner">
        <div class="container">
            <div class="about-banner__image" aria-hidden="true" style="background-image:url('<?= e(asset('images/site/screenshot-banner.webp')) ?>')"></div>
        </div>
    </section>

    <section class="about-intro section-pad">
        <div class="container about-intro__grid">
            <div>
                <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Who we are</p>
                <h2>Construction solutions,<br><span>grounded in Uganda.</span></h2>
            </div>
            <div class="about-intro__copy">
                <p><?= e(company_setting('company_description')) ?></p>
                <p>From early planning through to handover, we focus on clear communication, thoughtful coordination and work shaped around each client’s site and requirements.</p>
                <p class="about-intro__location"><?= e(company_setting('company_service_area')) ?></p>
                <a class="button button--primary" href="/quote.php">Discuss your project <span aria-hidden="true">↗</span></a>
            </div>
        </div>
    </section>

    <?php if ($teamMembers !== []): ?>
        <section class="about-team section-pad" aria-labelledby="about-team-title">
            <div class="container">
                <div class="section-heading">
                    <div>
                        <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> The people behind the work</p>
                        <h2 id="about-team-title">Meet our<br><span>team.</span></h2>
                    </div>
                </div>
                <div class="about-team__grid">
                    <?php foreach ($teamMembers as $member): ?>
                        <article class="premium-card about-team__card">
                            <?php if (!empty($member['image'])): ?>
                                <div class="image-wrap image-wrap--portrait">
                                    <img src="<?= e(asset((string) $member['image'])) ?>" alt="<?= e($member['name']) ?>" loading="lazy" width="600" height="800">
                                </div>
                            <?php endif; ?>
                            <div class="premium-card__body">
                                <h3 class="premium-card__title"><?= e($member['name']) ?></h3>
                                <p class="about-team__role"><?= e($member['job_title']) ?></p>
                                <?php if (!empty($member['bio'])): ?>
                                    <p class="premium-card__desc"><?= e($member['bio']) ?></p>
                                <?php endif; ?>
                            </div>
                        </article>
                    <?php endforeach; ?>
                </div>
            </div>
        </section>
    <?php endif; ?>

    <section class="about-visuals section-pad" aria-labelledby="about-visuals-title">
        <div class="container">
            <div class="section-heading reveal">
                <div>
                    <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Across the build</p>
                    <h2 id="about-visuals-title">People, planning<br><span>and places.</span></h2>
                </div>
                <p>Professional construction imagery helps show the people, planning, and places behind every project.</p>
            </div>
            <div class="across-build-grid">
                <article class="across-build-card reveal" data-category="people">
                    <div class="across-build-card__image">
                        <img src="<?= e(asset('images/across-build-people.webp')) ?>" alt="Construction professionals working on a building project" loading="lazy" width="1200" height="800">
                    </div>
                    <div class="across-build-card__body">
                        <span class="across-build-card__number">01</span>
                        <h3 class="across-build-card__title">People</h3>
                        <p class="across-build-card__desc">Construction professionals, teams and the people behind every project.</p>
                    </div>
                </article>
                <article class="across-build-card reveal" data-category="planning">
                    <div class="across-build-card__image">
                        <img src="<?= e(asset('images/across-build-planning.webp')) ?>" alt="Construction planning and engineering design drawings" loading="lazy" width="1200" height="800">
                    </div>
                    <div class="across-build-card__body">
                        <span class="across-build-card__number">02</span>
                        <h3 class="across-build-card__title">Planning</h3>
                        <p class="across-build-card__desc">Ideas, drawings, engineering and careful project planning.</p>
                    </div>
                </article>
                <article class="across-build-card reveal" data-category="places">
                    <div class="across-build-card__image">
                        <img src="<?= e(asset('images/across-build-places.webp')) ?>" alt="Completed modern building development project" loading="lazy" width="1200" height="800">
                    </div>
                    <div class="across-build-card__body">
                        <span class="across-build-card__number">03</span>
                        <h3 class="across-build-card__title">Places</h3>
                        <p class="across-build-card__desc">The buildings, developments and spaces brought from plans into reality.</p>
                    </div>
                </article>
            </div>
        </div>
    </section>

    <section class="about-approach section-pad">
        <div class="container">
            <div class="section-heading reveal">
                <div>
                    <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> How we work</p>
                    <h2>A considered process<br><span>from start to finish.</span></h2>
                </div>
                <p>Each project begins with a conversation and moves forward through practical, clearly discussed stages.</p>
            </div>
            <?php if ($processSteps !== []): ?>
                <ol class="about-process about-process--visual">
                    <?php foreach ($processSteps as $index => $step): ?>
                        <li class="reveal">
                            <?php if (!empty($step['image'])): ?>
                                <img src="<?= e(asset((string) $step['image'])) ?>" alt="" loading="lazy" width="600" height="400">
                            <?php endif; ?>
                            <span><?= e(sprintf('%02d', $index + 1)) ?></span>
                            <div>
                                <h3><?= e($step['title']) ?></h3>
                                <p><?= e($step['description']) ?></p>
                            </div>
                        </li>
                    <?php endforeach; ?>
                </ol>
            <?php endif; ?>
        </div>
    </section>

    <section class="about-safety safety--visual">
        <div class="container about-safety__grid">
            <div class="about-safety__media">
                <img src="<?= e(asset('images/site/safety-ppe.webp')) ?>" alt="Construction crew wearing safety helmets and high-visibility clothing on site" loading="lazy" width="1200" height="800">
                <div class="about-safety__thumbs" aria-hidden="true">
                    <img src="<?= e(asset('images/site/safety-inspection.webp')) ?>" alt="" loading="lazy" width="600" height="400">
                    <img src="<?= e(asset('images/site/site-engineers-supervision.webp')) ?>" alt="" loading="lazy" width="600" height="400">
                </div>
            </div>
            <div>
                <p class="eyebrow"><span class="eyebrow__line"></span> People first</p>
                <h2>Safety belongs<br>in every decision.</h2>
                <p>Site conditions change. Planning, protective equipment and regular supervision help keep people and work areas in focus throughout the job.</p>
                <ul>
                    <li>Appropriate personal protective equipment, helmets and safety boots</li>
                    <li>Site checks, inspections and clear work zones</li>
                    <li>Active coordination and construction supervision</li>
                </ul>
            </div>
        </div>
    </section>

    <section class="about-cta">
        <div class="container about-cta__inner">
            <h2>Have a project in mind?</h2>
            <a class="button button--primary" href="/quote.php">Request a Quote <span aria-hidden="true">↗</span></a>
        </div>
    </section>
</main>
<?php require PROJECT_ROOT . '/includes/footer.php'; ?>
