<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

$companyName = company_setting('company_name');
$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT, [
    'options' => ['min_range' => 1],
]);
$slug = filter_input(INPUT_GET, 'slug', FILTER_SANITIZE_SPECIAL_CHARS);

$project = null;
$images = [];
$databaseError = false;
$projectNotFound = false;
$allowedStatuses = [
    'completed' => 'Completed',
    'ongoing' => 'Ongoing',
    'upcoming' => 'Upcoming',
];

if ($id !== false && $id !== null) {
    try {
        $connection = db();
        $projectStatement = $connection->prepare(
            'SELECT id, title, slug, short_description, description, challenge, solution, results,
                materials_used, project_manager, location, project_type, client, status,
                start_date, completion_date, budget, featured_image, is_featured,
                is_published, is_demo, display_order
            FROM projects
            WHERE id = :id AND is_published = :published
            LIMIT 1'
        );
        $projectStatement->execute([
            'id' => $id,
            'published' => 1,
        ]);
        $project = $projectStatement->fetch() ?: null;

        if ($project !== null) {
            $imagesStatement = $connection->prepare(
                'SELECT id, image_path, alt_text, caption, category, display_order, is_featured
                FROM project_images
                WHERE project_id = :project_id
                ORDER BY display_order ASC, id ASC'
            );
            $imagesStatement->execute(['project_id' => $id]);
            $images = $imagesStatement->fetchAll();

            if (!empty($project['featured_image'])) {
                $featuredExists = false;
                foreach ($images as $image) {
                    if ($image['image_path'] === $project['featured_image']) {
                        $featuredExists = true;
                        break;
                    }
                }
                if (!$featuredExists) {
                    array_unshift($images, [
                        'id' => 0,
                        'image_path' => $project['featured_image'],
                        'alt_text' => $project['title'],
                        'caption' => null,
                        'category' => 'building-construction',
                        'display_order' => 0,
                        'is_featured' => 1,
                    ]);
                }
            }
        } else {
            $projectNotFound = true;
        }
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON project detail database query failed: ' . $error->getMessage());
        http_response_code(503);
        $databaseError = true;
    }
} else {
    $projectNotFound = true;
}

$pageTitle = $project !== null ? (string) $project['title'] . ' | ' . $companyName : 'Project details | ' . $companyName;
$pageDescription = $project !== null && !empty($project['short_description'])
    ? (string) $project['short_description']
    : ($project !== null ? mb_strimwidth((string) $project['description'], 0, 155, '…') : 'Explore construction project details from ' . $companyName . '.');
$canonicalUrl = $project !== null ? '/project-details.php?id=' . (int) $project['id'] : '/project-details.php';

$formatDate = static function (?string $value): string {
    if ($value === null || $value === '') {
        return 'To be confirmed';
    }
    try {
        return (new DateTimeImmutable($value))->format('d M Y');
    } catch (Exception $e) {
        return 'To be confirmed';
    }
};

$formatDuration = static function (?string $start, ?string $end): ?string {
    if ($start === null || $start === '') {
        return null;
    }
    try {
        $startDate = new DateTimeImmutable($start);
        if ($end === null || $end === '') {
            $endDate = new DateTimeImmutable();
        } else {
            $endDate = new DateTimeImmutable($end);
        }
        $interval = $startDate->diff($endDate);
        $months = $interval->y * 12 + $interval->m;
        $days = $interval->d;
        $parts = [];
        if ($months > 0) {
            $parts[] = $months === 1 ? '1 month' : $months . ' months';
        }
        if ($days > 0 || empty($parts)) {
            $parts[] = $days === 1 ? '1 day' : $days . ' days';
        }
        return implode(', ', $parts);
    } catch (Exception $e) {
        return null;
    }
};

$formatBudget = static function (?string $value): ?string {
    if ($value === null || $value === '' || !is_numeric($value)) {
        return null;
    }
    return 'UGX ' . number_format((float) $value, 0, '.', ',');
};

$featuredImagePath = $project !== null && !empty($project['featured_image'])
    ? (string) $project['featured_image']
    : ($images[0]['image_path'] ?? 'images/hero-construction.jpg');
$featuredImage = asset($featuredImagePath);
$featuredGalleryIndex = 0;
foreach ($images as $imageIndex => $galleryImage) {
    if ($galleryImage['image_path'] === $featuredImagePath) {
        $featuredGalleryIndex = $imageIndex;
        break;
    }
}

$processSteps = [
    ['title' => 'Site Preparation', 'description' => 'Clearing the site, setting out boundaries, and preparing the ground for construction works.'],
    ['title' => 'Foundation', 'description' => 'Excavation, reinforcement, and concrete foundation works to support the structure.'],
    ['title' => 'Structural Works', 'description' => 'Building the main structure including columns, beams, and floor slabs.'],
    ['title' => 'Roofing', 'description' => 'Installing the roof structure, covering, and weatherproofing elements.'],
    ['title' => 'Electrical & Plumbing', 'description' => 'Roughing in electrical conduits, wiring, and plumbing pipework throughout the building.'],
    ['title' => 'Finishing', 'description' => 'Plastering, flooring, painting, and final finishes to complete the interior and exterior.'],
    ['title' => 'Inspection & Handover', 'description' => 'Final quality inspection, defect rectification, and formal handover to the client.'],
];

require PROJECT_ROOT . '/includes/header.php';
$pageExtraHeadTags = '';
$pageExtraHeadTags .= '<link rel="canonical" href="' . e($canonicalUrl) . '">';
$pageExtraHeadTags .= '<meta property="og:title" content="' . e($pageTitle) . '">';
$pageExtraHeadTags .= '<meta property="og:description" content="' . e($pageDescription) . '">';
$pageExtraHeadTags .= '<meta property="og:type" content="website">';
$pageExtraHeadTags .= '<meta property="og:url" content="' . e($canonicalUrl) . '">';
if ($project !== null && !empty($project['featured_image'])) {
    $pageExtraHeadTags .= '<meta property="og:image" content="' . e(asset((string) $project['featured_image'])) . '">';
}
?>
<main id="main-content">
    <?php if ($databaseError): ?>
        <section class="section-pad">
            <div class="container">
                <div class="section-heading reveal">
                    <div>
                        <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Project details</p>
                        <h1>Project information is temporarily unavailable.</h1>
                    </div>
                </div>
                <p>Please try again shortly.</p>
                <a class="button button--primary" href="/projects.php">Back to projects <span aria-hidden="true">→</span></a>
            </div>
        </section>
    <?php elseif ($projectNotFound || $project === null): ?>
        <section class="section-pad">
            <div class="container">
                <div class="section-heading reveal">
                    <div>
                        <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> 404 · Project not found</p>
                        <h1>This project isn&rsquo;t available.</h1>
                    </div>
                </div>
                <p>The project may have been removed or is not currently published.</p>
                <a class="button button--primary" href="/projects.php">Browse projects <span aria-hidden="true">→</span></a>
            </div>
        </section>
    <?php else: ?>
        <?php
        $projectUrlSlug = !empty($project['slug']) ? $project['slug'] : 'id=' . (int) $project['id'];
        $budgetFormatted = $formatBudget((string) ($project['budget'] ?? ''));
        $durationFormatted = $formatDuration((string) ($project['start_date'] ?? ''), (string) ($project['completion_date'] ?? ''));
        $materialsList = !empty($project['materials_used']) ? array_map('trim', explode(',', (string) $project['materials_used'])) : [];
        ?>
        <nav class="breadcrumb" aria-label="Breadcrumb">
            <div class="container">
                <ol class="breadcrumb__list">
                    <li class="breadcrumb__item"><a href="/">Home</a><span aria-hidden="true"> → </span></li>
                    <li class="breadcrumb__item"><a href="/projects.php">Projects</a><span aria-hidden="true"> → </span></li>
                    <li class="breadcrumb__item breadcrumb__item--current"><?= e($project['title']) ?></li>
                </ol>
            </div>
        </nav>

        <section class="project-detail-hero reveal reveal-delay-1" style="background-image:url('<?= e($featuredImage) ?>')">
            <div class="project-detail-hero__shade" aria-hidden="true"></div>
            <div class="container project-detail-hero__inner">
                <a class="project-detail-hero__back" href="/projects.php"><span aria-hidden="true">←</span> All projects</a>
                <?php if ((int) $project['is_demo'] === 1): ?>
                    <span class="project-detail-hero__demo">Demonstration project · Sample content only</span>
                <?php endif; ?>
                <div class="project-detail-hero__content">
                    <span class="project-status project-status--<?= e($project['status']) ?>"><?= e($allowedStatuses[$project['status']] ?? ucfirst($project['status'])) ?></span>
                    <p class="project-detail-hero__type"><?= e($project['project_type']) ?></p>
                    <h1><?= e($project['title']) ?></h1>
                    <p class="project-detail-hero__location"><span aria-hidden="true">⌖</span> <?= e($project['location']) ?></p>
                </div>
            </div>
        </section>

        <?php if ((int) $project['is_demo'] === 1): ?>
            <div class="project-demo-notice" role="note">
                <div class="container"><strong>Demonstration content:</strong> This is fictional sample data for layout and workflow demonstration only. It is not represented as a real <?= e($companyName) ?> project; replace it with verified project information before publishing.</div>
            </div>
        <?php endif; ?>

        <section class="project-summary section-pad reveal reveal-delay-2">
            <div class="container">
                <div class="project-summary__grid">
                    <div class="project-summary__item">
                        <span class="project-summary__label">Project type</span>
                        <span class="project-summary__value"><?= e($project['project_type']) ?></span>
                    </div>
                    <div class="project-summary__item">
                        <span class="project-summary__label">Location</span>
                        <span class="project-summary__value"><?= e($project['location']) ?></span>
                    </div>
                    <?php if (!empty($project['client'])): ?>
                    <div class="project-summary__item">
                        <span class="project-summary__label">Client</span>
                        <span class="project-summary__value"><?= e($project['client']) ?></span>
                    </div>
                    <?php endif; ?>
                    <div class="project-summary__item">
                        <span class="project-summary__label">Status</span>
                        <span class="project-summary__value project-status project-status--<?= e($project['status']) ?>"><?= e($allowedStatuses[$project['status']] ?? ucfirst($project['status'])) ?></span>
                    </div>
                    <div class="project-summary__item">
                        <span class="project-summary__label">Start date</span>
                        <span class="project-summary__value"><?= e($formatDate((string) ($project['start_date'] ?? ''))) ?></span>
                    </div>
                    <div class="project-summary__item">
                        <span class="project-summary__label">Completion date</span>
                        <span class="project-summary__value"><?= e($formatDate((string) ($project['completion_date'] ?? ''))) ?></span>
                    </div>
                    <?php if ($durationFormatted !== null): ?>
                    <div class="project-summary__item">
                        <span class="project-summary__label">Duration</span>
                        <span class="project-summary__value"><?= e($durationFormatted) ?></span>
                    </div>
                    <?php endif; ?>
                    <?php if ($budgetFormatted !== null): ?>
                    <div class="project-summary__item">
                        <span class="project-summary__label">Budget</span>
                        <span class="project-summary__value"><?= e($budgetFormatted) ?></span>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
        </section>

        <section class="project-overview section-pad reveal reveal-delay-3">
            <div class="container project-overview__grid">
                <div class="project-overview__main">
                    <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Project overview</p>
                    <h2>Designed around<br><span>the project needs.</span></h2>
                    <div class="project-overview__description"><?= nl2br(e((string) $project['description'])) ?></div>
                </div>
                <?php if (!empty($project['challenge'])): ?>
                <div class="project-overview__challenge">
                    <div class="challenge-badge">The challenge</div>
                    <h3>What we faced</h3>
                    <p><?= nl2br(e((string) $project['challenge'])) ?></p>
                </div>
                <?php endif; ?>
                <?php if (!empty($project['solution'])): ?>
                <div class="project-overview__solution">
                    <div class="solution-badge">Our approach</div>
                    <h3>The solution</h3>
                    <p><?= nl2br(e((string) $project['solution'])) ?></p>
                </div>
                <?php endif; ?>
                <?php if (!empty($project['results'])): ?>
                <div class="project-overview__results">
                    <div class="results-badge">Project outcome</div>
                    <h3>What was achieved</h3>
                    <p><?= nl2br(e((string) $project['results'])) ?></p>
                </div>
                <?php endif; ?>
            </div>
        </section>

        <section class="project-process section-pad reveal reveal-delay-4">
            <div class="container">
                <div class="section-heading">
                    <div>
                        <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Construction process</p>
                        <h2>How we delivered<br><span>this project.</span></h2>
                    </div>
                </div>
                <div class="process-timeline">
                    <?php foreach ($processSteps as $index => $step): ?>
                        <div class="process-timeline__step reveal reveal-delay-<?= ($index % 3) + 1 ?>">
                            <div class="process-timeline__badge"><?= e(sprintf('%02d', $index + 1)) ?></div>
                            <div class="process-timeline__line"></div>
                            <div class="process-timeline__content">
                                <h3><?= e($step['title']) ?></h3>
                                <p><?= e($step['description']) ?></p>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
            </div>
        </section>

        <?php if ($images !== []): ?>
            <section class="project-gallery section-pad" aria-labelledby="gallery-title">
                <div class="container">
                    <div class="section-heading reveal">
                        <div>
                            <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Project gallery</p>
                            <h2 id="gallery-title">A closer look<br><span>at the project.</span></h2>
                        </div>
                        <p>Browse the project sequence, open any image in the full-screen viewer.</p>
                    </div>
                    <div class="project-gallery__viewer" data-project-gallery>
                        <?php $featuredGalleryImage = $images[$featuredGalleryIndex]; ?>
                        <button
                            class="project-gallery__featured"
                            type="button"
                            data-gallery-featured
                            data-gallery-index="<?= $featuredGalleryIndex ?>"
                            aria-label="Open featured project image in full screen viewer">
                            <img
                                data-gallery-featured-image
                                src="<?= e(asset((string) $featuredGalleryImage['image_path'])) ?>"
                                alt="<?= e((string) $featuredGalleryImage['alt_text']) ?>"
                                fetchpriority="high"
                                width="1920"
                                height="1280"
                                loading="eager">
                            <span class="project-gallery__featured-zoom" aria-hidden="true">⤢</span>
                            <span class="project-gallery__featured-hint">Open full gallery</span>
                            <span class="project-gallery__category" data-gallery-category><?= e(project_image_categories()[$featuredGalleryImage['category']] ?? 'Building Construction') ?></span>
                            <span class="project-gallery__position" data-gallery-counter><?= sprintf('%02d', $featuredGalleryIndex + 1) ?> / <?= sprintf('%02d', count($images)) ?></span>
                        </button>
                        <div class="project-gallery__info">
                            <p class="project-gallery__featured-caption" data-gallery-featured-caption <?= empty($featuredGalleryImage['caption']) ? 'hidden' : '' ?>><?= e((string) ($featuredGalleryImage['caption'] ?? '')) ?></p>
                            <span><?= count($images) ?> <?= count($images) === 1 ? 'image' : 'images' ?> · Select a thumbnail to explore</span>
                        </div>
                        <div class="project-gallery__thumbnails" role="group" aria-label="Project gallery thumbnails">
                        <?php foreach ($images as $index => $image): ?>
                            <button
                                class="project-gallery__thumbnail<?= $index === $featuredGalleryIndex ? ' is-current' : '' ?>"
                                type="button"
                                data-lightbox-src="<?= e(asset((string) $image['image_path'])) ?>"
                                data-lightbox-alt="<?= e($image['alt_text']) ?>"
                                data-lightbox-caption="<?= e($image['caption'] ?? '') ?>"
                                data-lightbox-category="<?= e(project_image_categories()[$image['category']] ?? 'Building Construction') ?>"
                                aria-label="Show image <?= $index + 1 ?> of <?= count($images) ?>: <?= e($image['alt_text']) ?>"
                                aria-pressed="<?= $index === $featuredGalleryIndex ? 'true' : 'false' ?>">
                                <img src="<?= e(asset(project_image_thumbnail_path((string) $image['image_path']))) ?>" alt="" loading="lazy" width="320" height="213">
                                <span><?= $index + 1 ?></span>
                            </button>
                        <?php endforeach; ?>
                        </div>
                    </div>
                </div>
                <dialog class="lightbox" aria-label="Project image viewer">
                    <div class="lightbox__toolbar">
                        <span class="lightbox__counter" aria-live="polite"></span>
                        <button class="lightbox__fullscreen" type="button" aria-label="View image full screen">Full screen</button>
                        <button class="lightbox__close" type="button" aria-label="Close image viewer">&times;</button>
                    </div>
                    <div class="lightbox__stage">
                        <button class="lightbox__previous" type="button" aria-label="Previous image" data-lightbox-prev>←</button>
                        <img class="lightbox__image" src="" alt="">
                        <button class="lightbox__next" type="button" aria-label="Next image" data-lightbox-next>→</button>
                    </div>
                    <p class="lightbox__caption"></p>
                    <p class="lightbox__help">Use ← → keys to navigate, Esc to close.</p>
                </dialog>
            </div>
        </section>
        <?php endif; ?>

        <?php if ($materialsList !== []): ?>
        <section class="project-scope section-pad reveal reveal-delay-5">
            <div class="container">
                <div class="section-heading">
                    <div>
                        <p class="eyebrow eyebrow--dark"><span class="eyebrow__line"></span> Scope of work</p>
                        <h2>What was delivered<br><span>on this project.</span></h2>
                    </div>
                </div>
                <div class="scope-grid">
                    <?php foreach ($materialsList as $index => $material): ?>
                        <div class="scope-item reveal reveal-delay-<?= ($index % 3) + 1 ?>">
                            <span class="scope-badge"><?= e(sprintf('%02d', $index + 1)) ?></span>
                            <span class="scope-name"><?= e($material) ?></span>
                        </div>
                    <?php endforeach; ?>
                </div>
            </div>
        </section>
        <?php endif; ?>

        <section class="cta reveal reveal-delay-7">
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
