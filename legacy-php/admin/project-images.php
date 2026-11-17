<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';
admin_require_manage('project_images');

$errors = [];
$projectId = filter_var(
    $_POST['project_id'] ?? $_GET['project_id'] ?? null,
    FILTER_VALIDATE_INT,
    ['options' => ['min_range' => 1]]
);
$selectedProjectId = $projectId === false ? null : $projectId;
$projects = [];
$images = [];
$selectedProject = null;

$imageById = static function (int $imageId, int $selectedId): array {
    $statement = db()->prepare(
        'SELECT id, project_id, image_path, alt_text, caption, category, display_order
        FROM project_images WHERE id = :id AND project_id = :project_id LIMIT 1'
    );
    $statement->execute(['id' => $imageId, 'project_id' => $selectedId]);
    $image = $statement->fetch();
    if (!is_array($image)) {
        throw new InvalidArgumentException('The project image no longer exists in this project.');
    }

    return $image;
};

$imagePathIsInUse = static function (string $path): bool {
    $statement = db()->prepare(
        'SELECT
            (SELECT COUNT(*) FROM project_images WHERE image_path = :gallery_path)
            + (SELECT COUNT(*) FROM projects WHERE featured_image = :featured_path)'
    );
    $statement->execute(['gallery_path' => $path, 'featured_path' => $path]);

    return (int) $statement->fetchColumn() > 0;
};

try {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (!admin_post_token_is_valid()) {
            http_response_code(400);
            exit('The request could not be verified. Reload the page and try again.');
        }

        if ($selectedProjectId === null) {
            throw new InvalidArgumentException('Select a project before managing its images.');
        }

        $action = (string) ($_POST['action'] ?? 'upload');
        if ($action === 'delete') {
            $imageId = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
            if ($imageId === false) {
                throw new InvalidArgumentException('Choose a valid project image.');
            }

            $image = $imageById($imageId, $selectedProjectId);
            $connection = db();
            $connection->beginTransaction();
            $delete = $connection->prepare('DELETE FROM project_images WHERE id = :id AND project_id = :project_id');
            $delete->execute(['id' => $imageId, 'project_id' => $selectedProjectId]);

            $featuredQuery = $connection->prepare('SELECT featured_image FROM projects WHERE id = :id');
            $featuredQuery->execute(['id' => $selectedProjectId]);
            if ($featuredQuery->fetchColumn() === $image['image_path']) {
                $nextImageQuery = $connection->prepare(
                    'SELECT image_path FROM project_images
                    WHERE project_id = :project_id ORDER BY display_order, id LIMIT 1'
                );
                $nextImageQuery->execute(['project_id' => $selectedProjectId]);
                $updateFeatured = $connection->prepare('UPDATE projects SET featured_image = :path WHERE id = :id');
                $updateFeatured->execute([
                    'path' => $nextImageQuery->fetchColumn() ?: null,
                    'id' => $selectedProjectId,
                ]);
            }
            $connection->commit();

            if (!$imagePathIsInUse((string) $image['image_path'])) {
                project_image_delete_files((string) $image['image_path']);
            }

            add_flash_message('success', 'Project image deleted.');
            admin_redirect('project-images.php?project_id=' . $selectedProjectId);
        }

        if ($action === 'update') {
            $imageId = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
            $altText = trim((string) ($_POST['alt_text'] ?? ''));
            $caption = trim((string) ($_POST['caption'] ?? ''));
            $category = trim((string) ($_POST['category'] ?? ''));
            $categories = project_image_categories();
            if ($imageId === false) {
                throw new InvalidArgumentException('Choose a valid project image.');
            }
            if ($altText === '' || mb_strlen($altText) > 255) {
                throw new InvalidArgumentException('Alt text is required and must be 255 characters or fewer.');
            }
            if (mb_strlen($caption) > 255) {
                throw new InvalidArgumentException('Captions must be 255 characters or fewer.');
            }
            if (!array_key_exists($category, $categories)) {
                throw new InvalidArgumentException('Choose a valid construction image category.');
            }

            $imageById($imageId, $selectedProjectId);
            $isFeatured = isset($_POST['is_featured']) && $_POST['is_featured'] === '1' ? 1 : 0;
            $update = db()->prepare(
                'UPDATE project_images SET alt_text = :alt_text, caption = :caption, category = :category, is_featured = :is_featured
                WHERE id = :id AND project_id = :project_id'
            );
            $update->execute([
                'alt_text' => $altText,
                'caption' => $caption !== '' ? $caption : null,
                'category' => $category,
                'is_featured' => $isFeatured,
                'id' => $imageId,
                'project_id' => $selectedProjectId,
            ]);

            // If this image is featured, unset featured flag on other images for this project
            if ($isFeatured === 1) {
                $unsetFeatured = db()->prepare(
                    'UPDATE project_images SET is_featured = 0 WHERE project_id = :project_id AND id != :id'
                );
                $unsetFeatured->execute(['project_id' => $selectedProjectId, 'id' => $imageId]);
            }

            add_flash_message('success', 'Image caption and alt text saved.');
            admin_redirect('project-images.php?project_id=' . $selectedProjectId);
        }

        if ($action === 'featured') {
            $imageId = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
            if ($imageId === false) {
                throw new InvalidArgumentException('Choose a valid project image.');
            }
            $image = $imageById($imageId, $selectedProjectId);
            $update = db()->prepare('UPDATE projects SET featured_image = :path WHERE id = :id');
            $update->execute(['path' => $image['image_path'], 'id' => $selectedProjectId]);
            add_flash_message('success', 'Featured project image updated.');
            admin_redirect('project-images.php?project_id=' . $selectedProjectId);
        }

        if ($action === 'replace') {
            $imageId = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
            if ($imageId === false) {
                throw new InvalidArgumentException('Choose a valid project image.');
            }

            $image = $imageById($imageId, $selectedProjectId);
            $newPath = project_image_upload($_FILES['replacement'] ?? []);
            $connection = db();
            try {
                $connection->beginTransaction();
                $replace = $connection->prepare(
                    'UPDATE project_images SET image_path = :new_path
                    WHERE id = :id AND project_id = :project_id'
                );
                $replace->execute([
                    'new_path' => $newPath,
                    'id' => $imageId,
                    'project_id' => $selectedProjectId,
                ]);
                $updateFeatured = $connection->prepare(
                    'UPDATE projects SET featured_image = :new_path
                    WHERE id = :project_id AND featured_image = :old_path'
                );
                $updateFeatured->execute([
                    'new_path' => $newPath,
                    'project_id' => $selectedProjectId,
                    'old_path' => $image['image_path'],
                ]);
                $connection->commit();
            } catch (Throwable $error) {
                if ($connection->inTransaction()) {
                    $connection->rollBack();
                }
                project_image_delete_files($newPath);
                throw $error;
            }

            if (!$imagePathIsInUse((string) $image['image_path'])) {
                project_image_delete_files((string) $image['image_path']);
            }
            add_flash_message('success', 'Project image replaced.');
            admin_redirect('project-images.php?project_id=' . $selectedProjectId);
        }

        if ($action === 'reorder') {
            $rawOrder = trim((string) ($_POST['order'] ?? ''));
            $order = $rawOrder === '' ? [] : explode(',', $rawOrder);
            $currentQuery = db()->prepare(
                'SELECT id FROM project_images WHERE project_id = :project_id ORDER BY display_order, id'
            );
            $currentQuery->execute(['project_id' => $selectedProjectId]);
            $currentIds = array_map('intval', array_column($currentQuery->fetchAll(), 'id'));
            $submittedIds = array_map('intval', $order);
            $sortedCurrentIds = $currentIds;
            $sortedSubmittedIds = $submittedIds;
            sort($sortedCurrentIds);
            sort($sortedSubmittedIds);

            if (
                count($submittedIds) !== count(array_unique($submittedIds))
                || $sortedCurrentIds !== $sortedSubmittedIds
            ) {
                throw new InvalidArgumentException('The image order changed. Reload the page and try again.');
            }

            $connection = db();
            $connection->beginTransaction();
            $updateOrder = $connection->prepare(
                'UPDATE project_images SET display_order = :display_order
                WHERE id = :id AND project_id = :project_id'
            );
            foreach ($submittedIds as $index => $imageId) {
                $updateOrder->execute([
                    'display_order' => $index,
                    'id' => $imageId,
                    'project_id' => $selectedProjectId,
                ]);
            }
            $connection->commit();
            add_flash_message('success', 'Project image order saved.');
            admin_redirect('project-images.php?project_id=' . $selectedProjectId);
        }

        if ($action !== 'upload') {
            throw new InvalidArgumentException('Choose a valid image management action.');
        }

        $altPrefix = trim((string) ($_POST['alt_text'] ?? ''));
        $caption = trim((string) ($_POST['caption'] ?? ''));
        $category = trim((string) ($_POST['category'] ?? 'building-construction'));
        $categories = project_image_categories();
        $files = $_FILES['images'] ?? null;
        if ($altPrefix === '' || mb_strlen($altPrefix) > 210) {
            throw new InvalidArgumentException('Enter a descriptive alt text prefix (210 characters maximum).');
        }
        if (mb_strlen($caption) > 255) {
            throw new InvalidArgumentException('Captions must be 255 characters or fewer.');
        }
        if (!array_key_exists($category, $categories)) {
            throw new InvalidArgumentException('Choose a valid construction image category.');
        }
        if (!is_array($files) || !is_array($files['name'] ?? null)) {
            throw new InvalidArgumentException('Choose at least one image to upload.');
        }

        $fileCount = count($files['name']);
        if ($fileCount < 1 || $fileCount > 30) {
            throw new InvalidArgumentException('Upload between 1 and 30 images per batch.');
        }

        $connection = db();
        $projectCheck = $connection->prepare('SELECT featured_image FROM projects WHERE id = :id');
        $projectCheck->execute(['id' => $selectedProjectId]);
        $currentFeaturedImage = $projectCheck->fetchColumn();
        if ($currentFeaturedImage === false) {
            throw new InvalidArgumentException('The selected project was not found.');
        }

        $orderQuery = $connection->prepare(
            'SELECT COALESCE(MAX(display_order) + 1, 0) FROM project_images WHERE project_id = :project_id'
        );
        $orderQuery->execute(['project_id' => $selectedProjectId]);
        $nextDisplayOrder = (int) $orderQuery->fetchColumn();
        if ($nextDisplayOrder + $fileCount > 65536) {
            throw new InvalidArgumentException('This project has reached the maximum number of ordered images.');
        }

        $savedPaths = [];
        $connection->beginTransaction();
        try {
            $insert = $connection->prepare(
                'INSERT INTO project_images (project_id, image_path, alt_text, caption, category, display_order)
                VALUES (:project_id, :image_path, :alt_text, :caption, :category, :display_order)'
            );
            foreach (array_keys($files['name']) as $index) {
                $file = [
                    'name' => $files['name'][$index] ?? '',
                    'tmp_name' => $files['tmp_name'][$index] ?? '',
                    'error' => $files['error'][$index] ?? UPLOAD_ERR_NO_FILE,
                    'size' => $files['size'][$index] ?? 0,
                ];
                $path = project_image_upload($file);
                $savedPaths[] = $path;
                $originalName = pathinfo((string) $file['name'], PATHINFO_FILENAME);
                $description = trim(preg_replace('/[\s_-]+/u', ' ', $originalName) ?? '');
                $altText = mb_strimwidth($altPrefix . ($description === '' ? '' : ': ' . $description), 0, 255);
                $insert->execute([
                    'project_id' => $selectedProjectId,
                    'image_path' => $path,
                    'alt_text' => $altText,
                    'caption' => $caption !== '' ? $caption : null,
                    'category' => $category,
                    'display_order' => $nextDisplayOrder++,
                ]);
            }

            if ($currentFeaturedImage === null || $currentFeaturedImage === '') {
                $setFeatured = $connection->prepare('UPDATE projects SET featured_image = :path WHERE id = :id');
                $setFeatured->execute(['path' => $savedPaths[0], 'id' => $selectedProjectId]);
            }
            $connection->commit();
        } catch (Throwable $error) {
            if ($connection->inTransaction()) {
                $connection->rollBack();
            }
            foreach ($savedPaths as $path) {
                project_image_delete_files($path);
            }
            throw $error;
        }

        add_flash_message('success', sprintf('%d project %s uploaded and optimized.', count($savedPaths), count($savedPaths) === 1 ? 'image' : 'images'));
        admin_redirect('project-images.php?project_id=' . $selectedProjectId);
    }

    $projectQuery = db()->prepare(
        'SELECT p.id, p.title, p.featured_image, COUNT(pi.id) AS image_count
        FROM projects p LEFT JOIN project_images pi ON pi.project_id = p.id
        GROUP BY p.id, p.title, p.featured_image ORDER BY p.title'
    );
    $projectQuery->execute();
    $projects = $projectQuery->fetchAll();

    if ($selectedProjectId === null && $projects !== []) {
        $selectedProjectId = (int) $projects[0]['id'];
    }

    foreach ($projects as $projectRow) {
        if ((int) $projectRow['id'] === $selectedProjectId) {
            $selectedProject = $projectRow;
            break;
        }
    }

    if ($selectedProjectId !== null && $selectedProject === null) {
        $errors[] = 'Select a valid project.';
        $selectedProjectId = null;
    }

    if ($selectedProjectId !== null) {
        $imagesQuery = db()->prepare(
            'SELECT id, image_path, alt_text, caption, category, display_order
            FROM project_images WHERE project_id = :project_id ORDER BY display_order, id'
        );
        $imagesQuery->execute(['project_id' => $selectedProjectId]);
        $images = $imagesQuery->fetchAll();
    }
} catch (InvalidArgumentException $error) {
    $errors[] = $error->getMessage();
} catch (PDOException | RuntimeException $error) {
    error_log('ICON project image management failed: ' . $error->getMessage());
    http_response_code(503);
    exit('Project image management is temporarily unavailable.');
}

require_once __DIR__ . '/_layout.php';
admin_start('Project images');
?>
<section class="admin-panel admin-gallery-selector">
    <div>
        <p class="admin-eyebrow">Organized by project</p>
        <h2><?= e((string) ($selectedProject['title'] ?? 'Choose a project')) ?></h2>
        <p>Select a project to upload, manage and order its gallery. Add images in batches (up to 30 at once); projects can hold 20–30+ images as needed.</p>
    </div>
    <form method="get" action="/admin/project-images.php" class="admin-project-picker">
        <label for="project-picker">Project</label>
        <select id="project-picker" name="project_id" onchange="this.form.submit()">
            <?php foreach ($projects as $projectOption): ?>
                <option value="<?= (int) $projectOption['id'] ?>" <?= (int) $projectOption['id'] === $selectedProjectId ? 'selected' : '' ?>>
                    <?= e($projectOption['title']) ?> · <?= (int) $projectOption['image_count'] ?> images
                </option>
            <?php endforeach; ?>
        </select>
        <noscript><button class="admin-button" type="submit">Show project</button></noscript>
    </form>
</section>
<?php if ($errors !== []): ?>
    <div class="admin-alert admin-alert--error" role="alert"><?php foreach ($errors as $error): ?><div><?= e($error) ?></div><?php endforeach; ?></div>
<?php endif; ?>
<?php if ($selectedProjectId !== null): ?>
    <section class="admin-panel admin-upload-panel">
        <div class="admin-panel__heading">
            <div><h2>Add project images</h2><p>JPEG, PNG or WebP · up to 5 MB each · optimized to WebP with listing thumbnails</p></div>
            <span><?= count($images) ?> images in this project</span>
        </div>
        <form class="admin-form admin-multi-upload" method="post" enctype="multipart/form-data" action="/admin/project-images.php?project_id=<?= $selectedProjectId ?>">
            <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
            <input type="hidden" name="project_id" value="<?= $selectedProjectId ?>">
            <input type="hidden" name="action" value="upload">
            <div class="admin-field admin-field--wide">
                <label for="image-files">Choose multiple images</label>
                <input id="image-files" name="images[]" type="file" accept="image/jpeg,image/png,image/webp" multiple required>
                <small>Up to 30 images per batch; drag files in or browse. Projects can accumulate 20–30+ images total. Thumbnail previews appear before upload.</small>
                <div class="admin-image-previews" data-upload-previews aria-live="polite"></div>
            </div>
            <div class="admin-field">
                <label for="alt-text-prefix">Descriptive alt text prefix *</label>
                <input id="alt-text-prefix" name="alt_text" maxlength="210" required placeholder="Construction crew at the project site">
                <small>The uploaded filename is appended to help distinguish images. You can refine each alt text below.</small>
            </div>
            <div class="admin-field">
                <label for="image-caption">Caption (optional)</label>
                <input id="image-caption" name="caption" maxlength="255" placeholder="Site preparation · sample project">
            </div>
            <div class="admin-field">
                <label for="image-category">Image category</label>
                <select id="image-category" name="category" required>
                    <?php foreach (project_image_categories() as $categoryValue => $categoryLabel): ?>
                        <option value="<?= e($categoryValue) ?>"><?= e($categoryLabel) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="admin-field admin-field--wide">
                <button class="admin-button admin-button--primary" type="submit">Upload selected images</button>
                <progress class="admin-upload-progress" value="0" max="100" hidden></progress>
                <span class="admin-upload-status" aria-live="polite"></span>
            </div>
        </form>
    </section>

    <section class="admin-panel admin-gallery-manager">
        <div class="admin-panel__heading">
            <div><h2>Project gallery</h2><p>Drag images to reorder or use the move controls. Save the order when you’re done.</p></div>
            <form class="admin-gallery-order-form" method="post" action="/admin/project-images.php?project_id=<?= $selectedProjectId ?>" data-order-form>
                <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                <input type="hidden" name="project_id" value="<?= $selectedProjectId ?>">
                <input type="hidden" name="action" value="reorder">
                <input type="hidden" name="order" value="">
                <button class="admin-button admin-button--primary" type="submit" <?= $images === [] ? 'disabled' : '' ?>>Save image order</button>
            </form>
        </div>
        <?php if ($images === []): ?>
            <p class="admin-empty">This project has no gallery images yet. Upload a set above to get started.</p>
        <?php else: ?>
            <div class="admin-image-grid" data-sortable-images>
                <?php foreach ($images as $index => $image): ?>
                    <?php $isFeatured = (string) $selectedProject['featured_image'] === (string) $image['image_path']; ?>
                    <article class="admin-image-card" draggable="true" data-image-id="<?= (int) $image['id'] ?>">
                        <div class="admin-image-card__media">
                            <img src="<?= e(asset(project_image_thumbnail_path((string) $image['image_path']))) ?>" alt="" loading="lazy" width="640" height="420">
                            <span class="admin-image-card__number"><?= $index + 1 ?></span>
                            <?php if ($isFeatured): ?><span class="admin-image-card__featured">Featured</span><?php endif; ?>
                        </div>
                        <div class="admin-image-card__controls">
                            <button class="admin-button admin-button--small" type="button" data-move-image="-1" aria-label="Move image <?= $index + 1 ?> earlier">↑</button>
                            <button class="admin-button admin-button--small" type="button" data-move-image="1" aria-label="Move image <?= $index + 1 ?> later">↓</button>
                            <span>Drag to reorder</span>
                        </div>
                        <form class="admin-image-card__metadata" method="post" action="/admin/project-images.php?project_id=<?= $selectedProjectId ?>">
                            <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                            <input type="hidden" name="project_id" value="<?= $selectedProjectId ?>">
                            <input type="hidden" name="action" value="update">
                            <input type="hidden" name="id" value="<?= (int) $image['id'] ?>">
                            <label>Alt text<input name="alt_text" maxlength="255" required value="<?= e((string) $image['alt_text']) ?>"></label>
                            <label>Caption<input name="caption" maxlength="255" value="<?= e((string) ($image['caption'] ?? '')) ?>"></label>
                            <label>Category<select name="category" required>
                                <?php foreach (project_image_categories() as $categoryValue => $categoryLabel): ?>
                                    <option value="<?= e($categoryValue) ?>" <?= $image['category'] === $categoryValue ? 'selected' : '' ?>><?= e($categoryLabel) ?></option>
                                <?php endforeach; ?>
                            </select></label>
                            <button class="admin-button admin-button--small" type="submit">Save details</button>
                        </form>
                        <div class="admin-image-card__actions">
                            <form method="post" action="/admin/project-images.php?project_id=<?= $selectedProjectId ?>">
                                <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                                <input type="hidden" name="project_id" value="<?= $selectedProjectId ?>">
                                <input type="hidden" name="action" value="featured">
                                <input type="hidden" name="id" value="<?= (int) $image['id'] ?>">
                                <button class="admin-button admin-button--small" type="submit" <?= $isFeatured ? 'disabled' : '' ?>><?= $isFeatured ? 'Featured image' : 'Set as featured' ?></button>
                            </form>
                            <form method="post" enctype="multipart/form-data" action="/admin/project-images.php?project_id=<?= $selectedProjectId ?>">
                                <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                                <input type="hidden" name="project_id" value="<?= $selectedProjectId ?>">
                                <input type="hidden" name="action" value="replace">
                                <input type="hidden" name="id" value="<?= (int) $image['id'] ?>">
                                <label class="admin-button admin-button--small admin-image-replace">Replace<input type="file" name="replacement" accept="image/jpeg,image/png,image/webp" required></label>
                            </form>
                            <form method="post" action="/admin/project-images.php?project_id=<?= $selectedProjectId ?>" onsubmit="return confirm('Delete this project image? This cannot be undone.');">
                                <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                                <input type="hidden" name="project_id" value="<?= $selectedProjectId ?>">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="id" value="<?= (int) $image['id'] ?>">
                                <button class="admin-button admin-button--danger admin-button--small" type="submit">Delete</button>
                            </form>
                        </div>
                    </article>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>
<?php else: ?>
    <section class="admin-panel"><p class="admin-empty">Add a project before uploading gallery images.</p></section>
<?php endif; ?>
<script src="/assets/js/project-images-admin.js" defer></script>
<?php admin_end(); ?>
