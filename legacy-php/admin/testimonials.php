<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';
admin_require_manage('testimonials');

$action = (string) ($_POST['action'] ?? $_GET['action'] ?? '');
$errors = [];
$recordId = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
$recordId = ($recordId !== false && $recordId > 0) ? $recordId : null;
$isNew = isset($_GET['new']) && $_GET['new'] === '1';
$filter = is_string($_GET['filter'] ?? null) ? $_GET['filter'] : 'all';

$db = db();
$projectsList = get_all_projects_for_testimonial_select();

// Handle POST actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!admin_post_token_is_valid()) {
        http_response_code(400);
        exit('The request could not be verified. Reload the page and try again.');
    }

    $postedAction = (string) ($_POST['action'] ?? 'save');
    $postedId = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);
    $postedId = ($postedId !== false && $postedId > 0) ? $postedId : null;

    // Action: Delete single testimonial
    if ($postedAction === 'delete' && $postedId !== null) {
        try {
            $stmt = $db->prepare('SELECT client_photo, company_logo FROM testimonials WHERE id = :id LIMIT 1');
            $stmt->execute(['id' => $postedId]);
            $existing = $stmt->fetch();

            if (is_array($existing)) {
                if (!empty($existing['client_photo'])) {
                    testimonial_delete_file((string) $existing['client_photo']);
                }
                if (!empty($existing['company_logo'])) {
                    testimonial_delete_file((string) $existing['company_logo']);
                }
            }

            $delete = $db->prepare('DELETE FROM testimonials WHERE id = :id');
            $delete->execute(['id' => $postedId]);
            add_flash_message('success', 'Testimonial deleted successfully.');
        } catch (Throwable $e) {
            error_log('Failed to delete testimonial: ' . $e->getMessage());
            add_flash_message('error', 'Could not delete testimonial.');
        }
        admin_redirect('testimonials.php');
    }

    // Action: Toggle Publish
    if ($postedAction === 'toggle_publish' && $postedId !== null) {
        try {
            $stmt = $db->prepare('SELECT is_published, client_permission FROM testimonials WHERE id = :id LIMIT 1');
            $stmt->execute(['id' => $postedId]);
            $record = $stmt->fetch();
            if ($record) {
                $newStatus = ((int) $record['is_published'] === 1) ? 0 : 1;
                $update = $db->prepare('UPDATE testimonials SET is_published = :status WHERE id = :id');
                $update->execute(['status' => $newStatus, 'id' => $postedId]);
                add_flash_message('success', $newStatus === 1 ? 'Testimonial published on website.' : 'Testimonial unpublished (moved to draft).');
            }
        } catch (Throwable $e) {
            error_log('Failed to toggle publish status: ' . $e->getMessage());
            add_flash_message('error', 'Could not update publication status.');
        }
        admin_redirect('testimonials.php');
    }

    // Action: Toggle Featured
    if ($postedAction === 'toggle_featured' && $postedId !== null) {
        try {
            $stmt = $db->prepare('SELECT is_featured FROM testimonials WHERE id = :id LIMIT 1');
            $stmt->execute(['id' => $postedId]);
            $record = $stmt->fetch();
            if ($record) {
                $newFeatured = ((int) $record['is_featured'] === 1) ? 0 : 1;
                $update = $db->prepare('UPDATE testimonials SET is_featured = :feat WHERE id = :id');
                $update->execute(['feat' => $newFeatured, 'id' => $postedId]);
                add_flash_message('success', $newFeatured === 1 ? 'Testimonial marked as featured.' : 'Testimonial unfeatured.');
            }
        } catch (Throwable $e) {
            error_log('Failed to toggle featured status: ' . $e->getMessage());
            add_flash_message('error', 'Could not update featured status.');
        }
        admin_redirect('testimonials.php');
    }

    // Action: Delete all demonstration testimonials
    if ($postedAction === 'delete_all_demo') {
        try {
            $count = delete_all_demonstration_testimonials();
            add_flash_message('success', sprintf('Cleaned up %d demonstration testimonial(s). Only verified client records remain.', $count));
        } catch (Throwable $e) {
            add_flash_message('error', 'Failed to remove demonstration testimonials: ' . $e->getMessage());
        }
        admin_redirect('testimonials.php');
    }

    // Action: Save (Create or Update)
    if ($postedAction === 'save') {
        $clientName = trim((string) ($_POST['client_name'] ?? ''));
        $clientRole = trim((string) ($_POST['client_role'] ?? ''));
        $company = trim((string) ($_POST['company'] ?? ''));
        $location = trim((string) ($_POST['location'] ?? ''));
        $quote = trim((string) ($_POST['quote'] ?? ''));
        $displayOrder = filter_var($_POST['display_order'] ?? 0, FILTER_VALIDATE_INT);
        $displayOrder = ($displayOrder !== false && $displayOrder >= 0) ? $displayOrder : 0;

        $ratingRaw = $_POST['rating'] ?? '';
        $rating = ($ratingRaw !== '' && ctype_digit((string) $ratingRaw)) ? (int) $ratingRaw : null;
        if ($rating !== null && ($rating < 1 || $rating > 5)) {
            $rating = null;
        }

        $isPublished = isset($_POST['is_published']) && $_POST['is_published'] === '1' ? 1 : 0;
        $isFeatured = isset($_POST['is_featured']) && $_POST['is_featured'] === '1' ? 1 : 0;
        $demonstrationContent = isset($_POST['demonstration_content']) && $_POST['demonstration_content'] === '1' ? 1 : 0;
        $clientPermission = isset($_POST['client_permission']) && $_POST['client_permission'] === '1' ? 1 : 0;

        // Project linkage
        $projectId = filter_var($_POST['project_id'] ?? null, FILTER_VALIDATE_INT);
        $projectId = ($projectId !== false && $projectId > 0) ? $projectId : null;
        $projectName = trim((string) ($_POST['project_name'] ?? ''));

        // If project selected from dropdown and project name is empty, fetch project title
        if ($projectId !== null && $projectName === '') {
            foreach ($projectsList as $p) {
                if ((int) $p['id'] === $projectId) {
                    $projectName = $p['title'];
                    break;
                }
            }
        }

        // Validations
        if ($clientName === '') {
            $errors['client_name'] = 'Client name is required.';
        } elseif (mb_strlen($clientName) > 160) {
            $errors['client_name'] = 'Client name cannot exceed 160 characters.';
        }

        if ($quote === '') {
            $errors['quote'] = 'Testimonial / review text is required.';
        }

        if (mb_strlen($clientRole) > 160) {
            $errors['client_role'] = 'Position / role cannot exceed 160 characters.';
        }

        if (mb_strlen($company) > 180) {
            $errors['company'] = 'Company name cannot exceed 180 characters.';
        }

        if (mb_strlen($location) > 180) {
            $errors['location'] = 'Location cannot exceed 180 characters.';
        }

        if (mb_strlen($projectName) > 180) {
            $errors['project_name'] = 'Project name cannot exceed 180 characters.';
        }

        // Fetch existing photos if editing
        $currentPhoto = null;
        $currentLogo = null;
        if ($postedId !== null) {
            $existingStmt = $db->prepare('SELECT client_photo, company_logo FROM testimonials WHERE id = :id LIMIT 1');
            $existingStmt->execute(['id' => $postedId]);
            $existingRecord = $existingStmt->fetch();
            if ($existingRecord) {
                $currentPhoto = $existingRecord['client_photo'];
                $currentLogo = $existingRecord['company_logo'];
            }
        }

        // Handle photo removal
        if (!empty($_POST['remove_client_photo']) && $currentPhoto !== null) {
            testimonial_delete_file((string) $currentPhoto);
            $currentPhoto = null;
        }

        // Handle logo removal
        if (!empty($_POST['remove_company_logo']) && $currentLogo !== null) {
            testimonial_delete_file((string) $currentLogo);
            $currentLogo = null;
        }

        // Process Client Photo Upload
        if (isset($_FILES['client_photo']) && ($_FILES['client_photo']['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_NO_FILE) {
            try {
                $uploadedPhoto = testimonial_photo_upload($_FILES['client_photo']);
                if ($currentPhoto !== null) {
                    testimonial_delete_file((string) $currentPhoto);
                }
                $currentPhoto = $uploadedPhoto;
            } catch (Throwable $e) {
                $errors['client_photo'] = $e->getMessage();
            }
        }

        // Process Company Logo Upload
        if (isset($_FILES['company_logo']) && ($_FILES['company_logo']['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_NO_FILE) {
            try {
                $uploadedLogo = testimonial_logo_upload($_FILES['company_logo']);
                if ($currentLogo !== null) {
                    testimonial_delete_file((string) $currentLogo);
                }
                $currentLogo = $uploadedLogo;
            } catch (Throwable $e) {
                $errors['company_logo'] = $e->getMessage();
            }
        }

        if ($errors === []) {
            try {
                if ($postedId === null) {
                    $insert = $db->prepare(
                        'INSERT INTO testimonials (
                            client_name, client_role, company, project_id, project_name, location,
                            client_photo, company_logo, quote, rating,
                            is_published, is_featured, demonstration_content, client_permission,
                            display_order
                        ) VALUES (
                            :client_name, :client_role, :company, :project_id, :project_name, :location,
                            :client_photo, :company_logo, :quote, :rating,
                            :is_published, :is_featured, :demonstration_content, :client_permission,
                            :display_order
                        )'
                    );
                    $insert->execute([
                        'client_name' => $clientName,
                        'client_role' => $clientRole !== '' ? $clientRole : null,
                        'company' => $company !== '' ? $company : null,
                        'project_id' => $projectId,
                        'project_name' => $projectName !== '' ? $projectName : null,
                        'location' => $location !== '' ? $location : null,
                        'client_photo' => $currentPhoto,
                        'company_logo' => $currentLogo,
                        'quote' => $quote,
                        'rating' => $rating,
                        'is_published' => $isPublished,
                        'is_featured' => $isFeatured,
                        'demonstration_content' => $demonstrationContent,
                        'client_permission' => $clientPermission,
                        'display_order' => $displayOrder,
                    ]);
                    add_flash_message('success', 'Testimonial added successfully.');
                } else {
                    $update = $db->prepare(
                        'UPDATE testimonials SET
                            client_name = :client_name,
                            client_role = :client_role,
                            company = :company,
                            project_id = :project_id,
                            project_name = :project_name,
                            location = :location,
                            client_photo = :client_photo,
                            company_logo = :company_logo,
                            quote = :quote,
                            rating = :rating,
                            is_published = :is_published,
                            is_featured = :is_featured,
                            demonstration_content = :demonstration_content,
                            client_permission = :client_permission,
                            display_order = :display_order
                        WHERE id = :id'
                    );
                    $update->execute([
                        'client_name' => $clientName,
                        'client_role' => $clientRole !== '' ? $clientRole : null,
                        'company' => $company !== '' ? $company : null,
                        'project_id' => $projectId,
                        'project_name' => $projectName !== '' ? $projectName : null,
                        'location' => $location !== '' ? $location : null,
                        'client_photo' => $currentPhoto,
                        'company_logo' => $currentLogo,
                        'quote' => $quote,
                        'rating' => $rating,
                        'is_published' => $isPublished,
                        'is_featured' => $isFeatured,
                        'demonstration_content' => $demonstrationContent,
                        'client_permission' => $clientPermission,
                        'display_order' => $displayOrder,
                        'id' => $postedId,
                    ]);
                    add_flash_message('success', 'Testimonial updated successfully.');
                }

                admin_redirect('testimonials.php');
            } catch (Throwable $e) {
                error_log('Failed to save testimonial: ' . $e->getMessage());
                $errors['general'] = 'Failed to save testimonial to database: ' . $e->getMessage();
            }
        }
    }
}

// Fetch record for editing
$record = [];
if ($recordId !== null) {
    try {
        $stmt = $db->prepare('SELECT * FROM testimonials WHERE id = :id LIMIT 1');
        $stmt->execute(['id' => $recordId]);
        $record = $stmt->fetch() ?: [];
        if ($record === []) {
            http_response_code(404);
            exit('Testimonial record not found.');
        }
    } catch (Throwable $e) {
        http_response_code(503);
        exit('Database error loading testimonial.');
    }
}

// Fetch list of testimonials for table
$rows = [];
$counts = ['all' => 0, 'published' => 0, 'draft' => 0, 'demo' => 0];

try {
    // Count stats
    $countStmt = $db->query(
        'SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN is_published = 1 AND demonstration_content = 0 THEN 1 ELSE 0 END) AS published_count,
            SUM(CASE WHEN is_published = 0 AND demonstration_content = 0 THEN 1 ELSE 0 END) AS draft_count,
            SUM(CASE WHEN demonstration_content = 1 THEN 1 ELSE 0 END) AS demo_count
        FROM testimonials'
    );
    $c = $countStmt->fetch();
    if ($c) {
        $counts['all'] = (int) ($c['total'] ?? 0);
        $counts['published'] = (int) ($c['published_count'] ?? 0);
        $counts['draft'] = (int) ($c['draft_count'] ?? 0);
        $counts['demo'] = (int) ($c['demo_count'] ?? 0);
    }

    $whereClause = match ($filter) {
        'published' => 'WHERE t.is_published = 1 AND t.demonstration_content = 0',
        'draft' => 'WHERE t.is_published = 0 AND t.demonstration_content = 0',
        'demo' => 'WHERE t.demonstration_content = 1',
        default => '',
    };

    $listStmt = $db->prepare(
        "SELECT t.*, p.title AS linked_project_title, p.slug AS linked_project_slug
        FROM testimonials t
        LEFT JOIN projects p ON t.project_id = p.id
        {$whereClause}
        ORDER BY t.display_order ASC, t.created_at DESC
        LIMIT 150"
    );
    $listStmt->execute();
    $rows = $listStmt->fetchAll() ?: [];
} catch (Throwable $e) {
    error_log('Failed to fetch testimonials list: ' . $e->getMessage());
}

require_once __DIR__ . '/_layout.php';
admin_start('Client Reviews / Testimonials');
?>

<div class="admin-testimonials-container">
    <?php if ($recordId !== null || $isNew || ($errors !== [] && isset($_POST['action']) && $_POST['action'] === 'save')): ?>
        <!-- ==========================================
             TESTIMONIAL EDITOR (ADD / EDIT)
             ========================================== -->
        <?php
        $formData = array_merge($record, $_POST);
        $editing = $recordId !== null;
        ?>
        <section class="admin-panel admin-editor">
            <div class="admin-panel__heading">
                <div>
                    <h2><?= $editing ? 'Edit Testimonial #' . $recordId : 'Add Genuine Client Testimonial' ?></h2>
                    <span class="admin-panel__intro">Ensure all details reflect verified client experiences with ICON Construction.</span>
                </div>
                <a href="/admin/testimonials.php" class="admin-button admin-button--small">← Back to list</a>
            </div>

            <?php if ($errors !== []): ?>
                <div class="admin-alert admin-alert--error" role="alert">
                    <strong>Please review the following errors:</strong>
                    <ul style="margin: 6px 0 0 18px; padding: 0;">
                        <?php foreach ($errors as $err): ?>
                            <li><?= e($err) ?></li>
                        <?php endforeach; ?>
                    </ul>
                </div>
            <?php endif; ?>

            <form class="admin-form" method="post" action="/admin/testimonials.php<?= $editing ? '?id=' . $recordId : '?new=1' ?>" enctype="multipart/form-data">
                <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                <input type="hidden" name="action" value="save">
                <?php if ($editing): ?>
                    <input type="hidden" name="id" value="<?= $recordId ?>">
                <?php endif; ?>

                <!-- Client Name -->
                <div class="admin-field">
                    <label for="field-client_name">Client Full Name *</label>
                    <input id="field-client_name" name="client_name" type="text" value="<?= e((string) ($formData['client_name'] ?? '')) ?>" required maxlength="160" placeholder="e.g. David Mukasa">
                    <small class="admin-panel__intro">Real name of the person providing the review.</small>
                    <?php if (isset($errors['client_name'])): ?><small class="admin-field__error"><?= e($errors['client_name']) ?></small><?php endif; ?>
                </div>

                <!-- Client Position / Role -->
                <div class="admin-field">
                    <label for="field-client_role">Position / Job Title</label>
                    <input id="field-client_role" name="client_role" type="text" value="<?= e((string) ($formData['client_role'] ?? '')) ?>" maxlength="160" placeholder="e.g. Managing Director, Homeowner, Project Lead">
                    <small class="admin-panel__intro">Professional title or capacity in relation to the project.</small>
                    <?php if (isset($errors['client_role'])): ?><small class="admin-field__error"><?= e($errors['client_role']) ?></small><?php endif; ?>
                </div>

                <!-- Company / Organization -->
                <div class="admin-field">
                    <label for="field-company">Company / Organization</label>
                    <input id="field-company" name="company" type="text" value="<?= e((string) ($formData['company'] ?? '')) ?>" maxlength="180" placeholder="e.g. Mukono Business Park Ltd">
                    <small class="admin-panel__intro">Only state verified organizations with permission to publish.</small>
                    <?php if (isset($errors['company'])): ?><small class="admin-field__error"><?= e($errors['company']) ?></small><?php endif; ?>
                </div>

                <!-- Location -->
                <div class="admin-field">
                    <label for="field-location">Location</label>
                    <input id="field-location" name="location" type="text" value="<?= e((string) ($formData['location'] ?? '')) ?>" maxlength="180" placeholder="e.g. Kololo, Kampala or Entebbe">
                    <?php if (isset($errors['location'])): ?><small class="admin-field__error"><?= e($errors['location']) ?></small><?php endif; ?>
                </div>

                <!-- Database Project Selection -->
                <div class="admin-field">
                    <label for="field-project_id">Connected Portfolio Project (Optional)</label>
                    <select id="field-project_id" name="project_id">
                        <option value="">-- No linked database project --</option>
                        <?php foreach ($projectsList as $p): ?>
                            <option value="<?= (int) $p['id'] ?>" <?= ((string) ($formData['project_id'] ?? '') === (string) $p['id']) ? 'selected' : '' ?>>
                                <?= e($p['title']) ?> (<?= e($p['project_type']) ?> - <?= e($p['location']) ?>)
                            </option>
                        <?php endforeach; ?>
                    </select>
                    <small class="admin-panel__intro">If selected, visitors can click the project name to view its dedicated portfolio case study.</small>
                </div>

                <!-- Custom Project Name -->
                <div class="admin-field">
                    <label for="field-project_name">Project or Service Name</label>
                    <input id="field-project_name" name="project_name" type="text" value="<?= e((string) ($formData['project_name'] ?? '')) ?>" maxlength="180" placeholder="e.g. Commercial Office Complex, Residential Villa">
                    <small class="admin-panel__intro">Shown as the project reference on the testimonial card.</small>
                </div>

                <!-- Star Rating -->
                <div class="admin-field">
                    <label for="field-rating">Star Rating (1 - 5)</label>
                    <select id="field-rating" name="rating">
                        <option value="">No rating / Not rated by client</option>
                        <option value="5" <?= ((string) ($formData['rating'] ?? '') === '5') ? 'selected' : '' ?>>★★★★★ (5 Stars - Excellent)</option>
                        <option value="4" <?= ((string) ($formData['rating'] ?? '') === '4') ? 'selected' : '' ?>>★★★★☆ (4 Stars - Very Good)</option>
                        <option value="3" <?= ((string) ($formData['rating'] ?? '') === '3') ? 'selected' : '' ?>>★★★☆☆ (3 Stars - Good)</option>
                        <option value="2" <?= ((string) ($formData['rating'] ?? '') === '2') ? 'selected' : '' ?>>★★☆☆☆ (2 Stars - Fair)</option>
                        <option value="1" <?= ((string) ($formData['rating'] ?? '') === '1') ? 'selected' : '' ?>>★☆☆☆☆ (1 Star - Poor)</option>
                    </select>
                    <small class="admin-panel__intro"><strong>Notice:</strong> Only select a star rating if the client explicitly supplied one. Do not artificially inflate ratings.</small>
                </div>

                <!-- Display Order -->
                <div class="admin-field">
                    <label for="field-display_order">Display Order</label>
                    <input id="field-display_order" name="display_order" type="number" min="0" max="65535" value="<?= (int) ($formData['display_order'] ?? 0) ?>">
                    <small class="admin-panel__intro">Lower numbers appear earlier in the carousel (0 = top priority).</small>
                </div>

                <!-- Review / Testimonial Text -->
                <div class="admin-field admin-field--wide">
                    <label for="field-quote">Client Review / Testimonial Quote *</label>
                    <textarea id="field-quote" name="quote" rows="5" required placeholder="Paste the client's genuine review here..."><?= e((string) ($formData['quote'] ?? '')) ?></textarea>
                    <small class="admin-panel__intro">Genuine testimonial quotation from the client or authorized representative.</small>
                    <?php if (isset($errors['quote'])): ?><small class="admin-field__error"><?= e($errors['quote']) ?></small><?php endif; ?>
                </div>

                <!-- Client Photo Upload -->
                <div class="admin-field">
                    <label for="field-client_photo">Client Photograph (Optional)</label>
                    <input id="field-client_photo" name="client_photo" type="file" accept="image/jpeg,image/png,image/webp">
                    <small class="admin-panel__intro">Upload a genuine photo provided with permission. Automatically cropped into a 1:1 square WebP avatar.</small>
                    <?php if (!empty($formData['client_photo'])): ?>
                        <div style="display: flex; align-items: center; gap: 12px; margin-top: 8px; padding: 8px; background: #fafbfa; border: 1px solid var(--admin-line); border-radius: 6px;">
                            <img src="<?= e(asset($formData['client_photo'])) ?>" alt="Current client photo" style="width: 50px; height: 50px; border-radius: 50%; object-fit: cover;">
                            <label style="font-size: 11px; cursor: pointer; color: var(--admin-red);">
                                <input type="checkbox" name="remove_client_photo" value="1"> Remove current photo
                            </label>
                        </div>
                    <?php endif; ?>
                    <?php if (isset($errors['client_photo'])): ?><small class="admin-field__error"><?= e($errors['client_photo']) ?></small><?php endif; ?>
                </div>

                <!-- Company Logo Upload -->
                <div class="admin-field">
                    <label for="field-company_logo">Client Organization Logo (Optional)</label>
                    <input id="field-company_logo" name="company_logo" type="file" accept="image/jpeg,image/png,image/webp,image/svg+xml">
                    <small class="admin-panel__intro">Upload official logo with permission. Alpha transparency is preserved.</small>
                    <?php if (!empty($formData['company_logo'])): ?>
                        <div style="display: flex; align-items: center; gap: 12px; margin-top: 8px; padding: 8px; background: #fafbfa; border: 1px solid var(--admin-line); border-radius: 6px;">
                            <img src="<?= e(asset($formData['company_logo'])) ?>" alt="Current company logo" style="max-height: 40px; max-width: 120px; object-fit: contain;">
                            <label style="font-size: 11px; cursor: pointer; color: var(--admin-red);">
                                <input type="checkbox" name="remove_company_logo" value="1"> Remove current logo
                            </label>
                        </div>
                    <?php endif; ?>
                    <?php if (isset($errors['company_logo'])): ?><small class="admin-field__error"><?= e($errors['company_logo']) ?></small><?php endif; ?>
                </div>

                <!-- Publication & Trust Controls -->
                <div class="admin-field admin-field--wide" style="padding: 16px; background: #f9fbf9; border: 1px solid #dbe3dc; border-radius: 8px; margin-top: 8px;">
                    <strong style="display: block; margin-bottom: 12px; font-size: 13px;">Trust, Privacy & Visibility Settings</strong>
                    
                    <div style="display: grid; gap: 10px;">
                        <label class="admin-check" style="min-height: auto;">
                            <input name="is_published" type="checkbox" value="1" <?= (int) ($formData['is_published'] ?? 0) === 1 ? 'checked' : '' ?>>
                            <span><strong>Publish on public website</strong> (only displays if demonstration content flag is unchecked)</span>
                        </label>

                        <label class="admin-check" style="min-height: auto;">
                            <input name="is_featured" type="checkbox" value="1" <?= (int) ($formData['is_featured'] ?? 0) === 1 ? 'checked' : '' ?>>
                            <span><strong>Featured review</strong> (prioritized in homepage slider rotation)</span>
                        </label>

                        <label class="admin-check" style="min-height: auto;">
                            <input name="client_permission" type="checkbox" value="1" <?= (int) ($formData['client_permission'] ?? 1) === 1 ? 'checked' : '' ?>>
                            <span><strong>Client permission confirmed:</strong> The client or authorized representative has granted explicit permission to publish this review and organization reference.</span>
                        </label>

                        <label class="admin-check" style="min-height: auto; color: #873a35;">
                            <input name="demonstration_content" type="checkbox" value="1" <?= (int) ($formData['demonstration_content'] ?? 0) === 1 ? 'checked' : '' ?>>
                            <span><strong>Mark as Demonstration Content:</strong> This is mock/development data. Demonstration reviews are strictly blocked from the public live website.</span>
                        </label>
                    </div>
                </div>

                <div class="admin-field admin-field--wide" style="display: flex; gap: 12px; margin-top: 10px;">
                    <button class="admin-button admin-button--primary" type="submit"><?= $editing ? 'Save Changes' : 'Create Testimonial' ?></button>
                    <a href="/admin/testimonials.php" class="admin-button">Cancel</a>
                </div>
            </form>
        </section>

    <?php else: ?>

        <!-- ==========================================
             TESTIMONIALS LIST VIEW
             ========================================== -->
        <div class="admin-toolbar" style="flex-wrap: wrap; gap: 14px;">
            <div>
                <p style="margin: 0; font-weight: 600; font-size: 14px;">Real Client Reviews & Testimonials</p>
                <p style="margin: 4px 0 0; color: var(--admin-muted); font-size: 12px;">
                    Public website displays published, non-demo reviews only. Total: <?= $counts['all'] ?> | Published: <?= $counts['published'] ?> | Draft: <?= $counts['draft'] ?>
                </p>
            </div>
            <div style="display: flex; gap: 10px;">
                <a class="admin-button admin-button--primary" href="/admin/testimonials.php?new=1">+ Add Client Testimonial</a>
            </div>
        </div>

        <!-- Demonstration Notice & Cleanup Banner -->
        <?php if ($counts['demo'] > 0): ?>
            <div class="admin-alert" style="background: #fff8e6; border: 1px solid #f1d488; color: #7c570b; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px;">
                <div>
                    <strong>⚠️ Demonstration Content Alert:</strong>
                    <span>You have <?= $counts['demo'] ?> sample/demonstration testimonial(s). These are safely hidden from the live website.</span>
                </div>
                <form method="post" action="/admin/testimonials.php" onsubmit="return confirm('Permanently delete all demonstration testimonials and their sample images? Genuine client records will NOT be touched.');">
                    <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                    <input type="hidden" name="action" value="delete_all_demo">
                    <button class="admin-button admin-button--danger admin-button--small" type="submit">Remove All Demonstration Data</button>
                </form>
            </div>
        <?php endif; ?>

        <!-- Filter Navigation -->
        <div style="display: flex; gap: 6px; margin-bottom: 16px; border-bottom: 1px solid var(--admin-line); padding-bottom: 8px;">
            <a href="/admin/testimonials.php?filter=all" class="admin-button admin-button--small <?= $filter === 'all' ? 'admin-button--primary' : '' ?>">All (<?= $counts['all'] ?>)</a>
            <a href="/admin/testimonials.php?filter=published" class="admin-button admin-button--small <?= $filter === 'published' ? 'admin-button--primary' : '' ?>">Published (<?= $counts['published'] ?>)</a>
            <a href="/admin/testimonials.php?filter=draft" class="admin-button admin-button--small <?= $filter === 'draft' ? 'admin-button--primary' : '' ?>">Drafts (<?= $counts['draft'] ?>)</a>
            <?php if ($counts['demo'] > 0): ?>
                <a href="/admin/testimonials.php?filter=demo" class="admin-button admin-button--small <?= $filter === 'demo' ? 'admin-button--danger' : '' ?>">Demo Data (<?= $counts['demo'] ?>)</a>
            <?php endif; ?>
        </div>

        <section class="admin-panel admin-table-wrap">
            <?php if ($rows === []): ?>
                <div style="text-align: center; padding: 48px 24px;">
                    <div style="font-size: 36px; margin-bottom: 12px;">💬</div>
                    <h3 style="margin: 0 0 6px; font-size: 16px;">No testimonials found</h3>
                    <p style="margin: 0 0 16px; color: var(--admin-muted); font-size: 13px;">
                        <?= $filter === 'all' ? 'No client testimonials have been recorded yet.' : 'No testimonials match the selected filter.' ?>
                    </p>
                    <a href="/admin/testimonials.php?new=1" class="admin-button admin-button--primary">+ Add the First Testimonial</a>
                </div>
            <?php else: ?>
                <table class="admin-table">
                    <thead>
                        <tr>
                            <th scope="col" style="width: 50px;">Photo</th>
                            <th scope="col">Client & Role</th>
                            <th scope="col">Company & Location</th>
                            <th scope="col">Project Link</th>
                            <th scope="col">Rating</th>
                            <th scope="col">Status</th>
                            <th scope="col">Order</th>
                            <th scope="col" style="text-align: right;">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($rows as $row): ?>
                            <?php
                            $isPublished = (int) ($row['is_published'] ?? 0) === 1;
                            $isFeatured = (int) ($row['is_featured'] ?? 0) === 1;
                            $isDemo = (int) ($row['demonstration_content'] ?? 0) === 1;
                            ?>
                            <tr>
                                <!-- Photo / Avatar -->
                                <td>
                                    <?php if (!empty($row['client_photo'])): ?>
                                        <img src="<?= e(asset($row['client_photo'])) ?>" alt="<?= e($row['client_name']) ?>" style="width: 40px; height: 40px; border-radius: 50%; object-fit: cover; border: 1px solid var(--admin-line);">
                                    <?php else: ?>
                                        <div style="width: 40px; height: 40px; border-radius: 50%; background: #e5e9e5; color: #405045; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 14px;">
                                            <?= strtoupper(substr(trim((string) $row['client_name']), 0, 1)) ?>
                                        </div>
                                    <?php endif; ?>
                                </td>

                                <!-- Client & Role -->
                                <td>
                                    <strong><?= e($row['client_name']) ?></strong>
                                    <?php if (!empty($row['client_role'])): ?>
                                        <br><small style="color: var(--admin-muted);"><?= e($row['client_role']) ?></small>
                                    <?php endif; ?>
                                    <div style="margin-top: 4px; font-size: 11px; color: #555; max-width: 320px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="<?= e($row['quote']) ?>">
                                        “<?= e($row['quote']) ?>”
                                    </div>
                                </td>

                                <!-- Company & Location -->
                                <td>
                                    <?= e($row['company'] ?? '—') ?>
                                    <?php if (!empty($row['location'])): ?>
                                        <br><small style="color: var(--admin-muted);"><?= e($row['location']) ?></small>
                                    <?php endif; ?>
                                </td>

                                <!-- Project Link -->
                                <td>
                                    <?php if (!empty($row['linked_project_title'])): ?>
                                        <a href="/admin/manage.php?type=projects&amp;id=<?= (int) $row['project_id'] ?>" style="color: #2b593f; font-weight: 600; text-decoration: underline;" title="View database project">
                                            <?= e($row['linked_project_title']) ?> ↗
                                        </a>
                                    <?php elseif (!empty($row['project_name'])): ?>
                                        <span><?= e($row['project_name']) ?></span>
                                    <?php else: ?>
                                        <span style="color: var(--admin-muted);">—</span>
                                    <?php endif; ?>
                                </td>

                                <!-- Rating -->
                                <td>
                                    <?php if (!empty($row['rating']) && (int) $row['rating'] >= 1): ?>
                                        <span style="color: #d7a928; font-size: 14px; letter-spacing: 1px;">
                                            <?= str_repeat('★', (int) $row['rating']) . str_repeat('☆', 5 - (int) $row['rating']) ?>
                                        </span>
                                    <?php else: ?>
                                        <small style="color: var(--admin-muted);">Unrated</small>
                                    <?php endif; ?>
                                </td>

                                <!-- Status Badges & Quick Toggles -->
                                <td>
                                    <div style="display: flex; flex-direction: column; gap: 4px;">
                                        <!-- Publish Toggle -->
                                        <form method="post" action="/admin/testimonials.php" style="margin: 0;">
                                            <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                                            <input type="hidden" name="action" value="toggle_publish">
                                            <input type="hidden" name="id" value="<?= (int) $row['id'] ?>">
                                            <button type="submit" style="border: 0; background: none; padding: 0; cursor: pointer;">
                                                <?php if ($isPublished): ?>
                                                    <span style="display: inline-block; padding: 2px 7px; border-radius: 4px; font-size: 10px; font-weight: 700; background: #e2f4e8; color: #185a2d;" title="Click to unpublish">Published ✓</span>
                                                <?php else: ?>
                                                    <span style="display: inline-block; padding: 2px 7px; border-radius: 4px; font-size: 10px; font-weight: 700; background: #e9ece9; color: #586159;" title="Click to publish">Draft</span>
                                                <?php endif; ?>
                                            </button>
                                        </form>

                                        <!-- Featured Toggle -->
                                        <form method="post" action="/admin/testimonials.php" style="margin: 0;">
                                            <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                                            <input type="hidden" name="action" value="toggle_featured">
                                            <input type="hidden" name="id" value="<?= (int) $row['id'] ?>">
                                            <button type="submit" style="border: 0; background: none; padding: 0; cursor: pointer;">
                                                <?php if ($isFeatured): ?>
                                                    <span style="display: inline-block; padding: 1px 6px; border-radius: 4px; font-size: 9px; font-weight: 700; background: #fdf3d8; color: #8e680a;" title="Click to unfeature">★ Featured</span>
                                                <?php endif; ?>
                                            </button>
                                        </form>

                                        <!-- Demo Badge -->
                                        <?php if ($isDemo): ?>
                                            <span style="display: inline-block; padding: 1px 6px; border-radius: 4px; font-size: 9px; font-weight: 700; background: #feebe8; color: #9d2b24;" title="Development demonstration data only">DEMO CONTENT</span>
                                        <?php endif; ?>
                                    </div>
                                </td>

                                <!-- Order -->
                                <td><?= (int) $row['display_order'] ?></td>

                                <!-- Actions -->
                                <td style="text-align: right;">
                                    <div class="admin-row-actions" style="justify-content: flex-end;">
                                        <a class="admin-button admin-button--small" href="/admin/testimonials.php?id=<?= (int) $row['id'] ?>">Edit</a>
                                        <form method="post" action="/admin/testimonials.php" onsubmit="return confirm('Permanently delete testimonial from <?= e($row['client_name']) ?>?');">
                                            <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                                            <input type="hidden" name="action" value="delete">
                                            <input type="hidden" name="id" value="<?= (int) $row['id'] ?>">
                                            <button class="admin-button admin-button--danger admin-button--small" type="submit">Delete</button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </section>
    <?php endif; ?>
</div>

<?php admin_end(); ?>
