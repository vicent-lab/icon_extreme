<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

$companyName = company_setting('company_name');
$pageTitle = 'Projects | ' . $companyName;
$pageDescription = 'Explore ICON Construction Company project portfolio.';
$pageExtraHeadTags = '<link rel="canonical" href="/projects.php">';

require PROJECT_ROOT . '/includes/header.php';
?>
<main id="main-content">

    <section class="hero reveal" style="background:var(--color-concrete);color:var(--color-ink-deep);padding-block:80px;">
        <div class="container hero__inner">
            <p class="eyebrow eyebrow--dark reveal reveal-delay-1"><span class="eyebrow__line"></span> <?= e($companyName) ?> Projects</p>
            <h1 class="reveal reveal-delay-2">Featured Projects</h1>
            <p class="hero__intro reveal reveal-delay-3">Explore selected projects and discover the quality behind every structure.</p>
        </div>
    </section>

    <section class="projects section-pad">
        <div class="container">
            <div class="project-grid">
                <?php
                $hasProjects = false;
                $databaseReady = getenv('DB_HOST') !== false
                    && getenv('DB_NAME') !== false
                    && getenv('DB_USER') !== false
                    && getenv('DB_PASSWORD') !== false;

                if ($databaseReady) {
                    try {
                        $connection = db();
                        $statement = $connection->prepare(
                            'SELECT p.id, p.title, p.slug, p.location, p.project_type, p.status, p.description,
                                COALESCE(NULLIF(p.featured_image, \'\'), (
                                    SELECT pi.image_path FROM project_images pi
                                    WHERE pi.project_id = p.id ORDER BY pi.display_order, pi.id LIMIT 1
                                )) AS featured_image
                            FROM projects p
                            WHERE p.is_published = :published
                            ORDER BY p.is_featured DESC, p.display_order ASC, p.created_at DESC'
                        );
                        $statement->execute(['published' => 1]);
                        $dbProjects = $statement->fetchAll();
                        $hasProjects = count($dbProjects) > 0;
                    } catch (PDOException | RuntimeException $error) {
                        error_log('ICON projects page query failed: ' . $error->getMessage());
                        $dbProjects = [];
                    }
                }

                if ($hasProjects):
                    foreach ($dbProjects as $index => $project):
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
                    <?php endforeach;
                else: ?>
                    <div class="projects-empty reveal reveal-delay-2">
                        <span class="projects-empty__icon" aria-hidden="true">⌂</span>
                        <div>
                            <h3>Our project portfolio is taking shape.</h3>
                            <p>Featured projects will appear here as they are added to the company portfolio.</p>
                        </div>
                        <a class="text-link text-link--light" href="/quote.php">Discuss Your Project <span aria-hidden="true">→</span></a>
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </section>

</main>
<?php require PROJECT_ROOT . '/includes/footer.php'; ?>
