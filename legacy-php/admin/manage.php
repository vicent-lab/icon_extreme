<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';
require_admin_role();

$resources = [
    'projects' => [
        'title' => 'Projects',
        'table' => 'projects',
        'section' => 'projects',
        'fields' => [
            'title' => ['Title', 'text', true, 180],
            'slug' => ['Slug', 'text', true, 200],
            'short_description' => ['Short summary', 'textarea', false, 500],
            'project_type' => ['Project type', 'text', true, 120],
            'location' => ['Location', 'text', true, 180],
            'client' => ['Client name', 'text', false, 180],
            'project_manager' => ['Project manager', 'text', false, 160],
            'status' => ['Project status', 'select', true, ['completed', 'ongoing', 'upcoming']],
            'start_date' => ['Start date', 'date', false, 0],
            'completion_date' => ['Completion date', 'date', false, 0],
            'budget' => ['Budget (UGX)', 'number', false, 0],
            'featured_image' => ['Featured image', 'image', false, 255],
            'description' => ['Detailed project overview', 'textarea', true, 0],
            'challenge' => ['The Challenge (what we faced)', 'textarea', false, 0],
            'solution' => ['Our Solution / Approach', 'textarea', false, 0],
            'results' => ['Project Results / Outcome', 'textarea', false, 0],
            'materials_used' => ['Materials / Scope (comma separated)', 'textarea', false, 0],
            'is_featured' => ['Featured project', 'checkbox', false, 0],
            'is_published' => ['Visible on website', 'checkbox', false, 0],
            'is_demo' => ['Demonstration content', 'checkbox', false, 0],
            'display_order' => ['Display order', 'number', true, 0],
        ],
        'columns' => ['title', 'project_type', 'location', 'status', 'is_published'],
        'order_by' => 'display_order ASC, created_at DESC',
    ],
    'services' => [
        'title' => 'Services',
        'table' => 'services',
        'section' => 'services',
        'fields' => [
            'name' => ['Name', 'text', true, 160],
            'slug' => ['Slug', 'text', true, 180],
            'icon' => ['Icon key (e.g. building, tools, hard-hat, paint-roller, wrench, truck)', 'text', true, 80],
            'image' => ['Service image', 'image', false, 255],
            'short_description' => ['Short description', 'textarea', true, 500],
            'full_description' => ['Full description', 'textarea', true, 0],
            'status' => ['Status', 'select', true, ['active', 'inactive']],
            'is_featured' => ['Featured service', 'checkbox', false, 0],
            'display_order' => ['Display order', 'number', true, 0],
        ],
        'columns' => ['name', 'slug', 'status', 'is_featured', 'display_order'],
        'order_by' => 'display_order ASC, name ASC',
    ],
    'team_members' => [
        'title' => 'Team Members',
        'table' => 'team_members',
        'section' => 'team_members',
        'fields' => [
            'name' => ['Full name', 'text', true, 160],
            'job_title' => ['Job title / role', 'text', true, 160],
            'bio' => ['Biography / experience', 'textarea', false, 0],
            'image' => ['Profile photo', 'image', false, 255],
            'status' => ['Status', 'select', true, ['active', 'inactive']],
            'display_order' => ['Display order', 'number', true, 0],
        ],
        'columns' => ['name', 'job_title', 'status', 'display_order'],
        'order_by' => 'display_order ASC, name ASC',
    ],
    'blog_categories' => [
        'title' => 'Blog Categories',
        'table' => 'blog_categories',
        'section' => 'blog_categories',
        'fields' => [
            'name' => ['Category name', 'text', true, 120],
            'slug' => ['Slug', 'text', true, 140],
            'description' => ['Description', 'textarea', false, 500],
        ],
        'columns' => ['name', 'slug'],
        'order_by' => 'name ASC',
    ],
    'blog_posts' => [
        'title' => 'Blog Posts',
        'table' => 'blog_posts',
        'section' => 'blog_posts',
        'fields' => [
            'title' => ['Article title', 'text', true, 200],
            'slug' => ['Slug', 'text', true, 220],
            'category_id' => ['Category', 'category_select', false, 0],
            'author' => ['Author', 'text', false, 160],
            'featured_image' => ['Featured image', 'image', false, 255],
            'status' => ['Status', 'select', true, ['draft', 'published']],
            'reading_time' => ['Estimated reading time (minutes)', 'number', false, 0],
            'excerpt' => ['Excerpt summary', 'textarea', false, 500],
            'content' => ['Article content', 'textarea', true, 0],
            'seo_title' => ['SEO Meta Title', 'text', false, 255],
            'seo_description' => ['SEO Meta Description', 'textarea', false, 500],
        ],
        'columns' => ['title', 'status', 'published_at', 'created_at'],
        'order_by' => 'created_at DESC',
    ],
    'contact_messages' => [
        'title' => 'Contact Messages',
        'table' => 'contact_messages',
        'section' => 'contact_messages',
        'fields' => [
            'full_name' => ['Sender name', 'text', true, 160],
            'email' => ['Email address', 'text', true, 190],
            'phone' => ['Phone number', 'text', false, 40],
            'subject' => ['Subject', 'text', false, 200],
            'status' => ['Status', 'select', true, ['new', 'in_progress', 'replied', 'closed']],
            'message' => ['Message body', 'textarea', true, 0],
        ],
        'columns' => ['full_name', 'email', 'phone', 'status', 'created_at'],
        'order_by' => 'created_at DESC',
    ],
    'quote_requests' => [
        'title' => 'Quote Requests',
        'table' => 'quote_requests',
        'section' => 'quote_requests',
        'fields' => [
            'full_name' => ['Full name', 'text', true, 160],
            'phone' => ['Phone number', 'text', true, 40],
            'email' => ['Email address', 'text', true, 190],
            'location' => ['Project location', 'text', true, 180],
            'project_type' => ['Project type', 'text', true, 160],
            'estimated_budget' => ['Estimated budget (UGX)', 'number', false, 0],
            'preferred_contact_method' => ['Preferred contact method', 'select', true, ['phone', 'email', 'whatsapp']],
            'status' => ['Status', 'select', true, ['new', 'in_progress', 'quoted', 'closed']],
            'project_description' => ['Project description', 'textarea', true, 0],
        ],
        'columns' => ['full_name', 'project_type', 'location', 'status', 'created_at'],
        'order_by' => 'created_at DESC',
    ],
];

$type = (string) ($_GET['type'] ?? $_POST['type'] ?? 'projects');

if (!isset($resources[$type])) {
    http_response_code(404);
    exit('Resource not found.');
}

$resource = $resources[$type];

if (!admin_can_manage($resource['section'])) {
    http_response_code(403);
    exit('You do not have permission to manage this section.');
}

$db = db();
$errors = [];
$action = (string) ($_POST['action'] ?? $_GET['action'] ?? '');
$recordId = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
$recordId = ($recordId !== false && $recordId > 0) ? $recordId : null;
$isNew = isset($_GET['new']) && $_GET['new'] === '1';

// Load blog categories if needed
$blogCategories = [];
if ($type === 'blog_posts') {
    try {
        $catStmt = $db->query('SELECT id, name FROM blog_categories ORDER BY name ASC');
        $blogCategories = $catStmt->fetchAll() ?: [];
    } catch (Throwable $e) {
        // Ignored
    }
}

// Handle POST actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!admin_post_token_is_valid()) {
        http_response_code(400);
        exit('The request could not be verified. Reload the page and try again.');
    }

    $postedAction = (string) ($_POST['action'] ?? 'save');
    $postedId = filter_var($_POST['id'] ?? null, FILTER_VALIDATE_INT);
    $postedId = ($postedId !== false && $postedId > 0) ? $postedId : null;

    if ($postedAction === 'delete' && ($_SESSION['admin']['role'] ?? '') !== 'admin' && in_array($type, ['contact_messages', 'quote_requests', 'blog_posts', 'projects'], true)) {
        http_response_code(403);
        exit('Only administrators can delete this kind of record.');
    }

    if ($postedAction === 'delete' && $postedId !== null) {
        try {
            $stmt = $db->prepare('DELETE FROM ' . $resource['table'] . ' WHERE id = :id');
            $stmt->execute(['id' => $postedId]);
            add_flash_message('success', $resource['title'] . ' record deleted.');
        } catch (Throwable $e) {
            error_log('Failed to delete ' . $type . ': ' . $e->getMessage());
            add_flash_message('error', 'Could not delete this record. It may be in use elsewhere.');
        }
        admin_redirect('manage.php?type=' . urlencode($type));
    }

    $statusOnlyTypes = ['contact_messages', 'quote_requests'];

    if ($postedAction === 'save') {
        $values = [];
        foreach ($resource['fields'] as $name => [$label, $kind, $required, $constraint]) {
            if (in_array($type, $statusOnlyTypes, true) && $name !== 'status') {
                continue; // customer-submitted content is read-only
            }
            if ($kind === 'checkbox') {
                $values[$name] = isset($_POST[$name]) && $_POST[$name] === '1' ? 1 : 0;
            } elseif ($kind === 'number') {
                $val = trim((string) ($_POST[$name] ?? ''));
                if ($val === '') {
                    if ($required) {
                        $errors[$name] = $label . ' is required.';
                    } else {
                        $values[$name] = null;
                    }
                } else {
                    $values[$name] = is_numeric($val) ? (float) $val : 0;
                }
            } elseif ($kind === 'category_select') {
                $val = filter_var($_POST[$name] ?? null, FILTER_VALIDATE_INT);
                $values[$name] = ($val !== false && $val > 0) ? $val : null;
            } elseif ($kind === 'image') {
                $fileKey = $name . '_file';
                if (isset($_FILES[$fileKey]) && ($_FILES[$fileKey]['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK && ($_FILES[$fileKey]['size'] ?? 0) > 0) {
                    try {
                        $uploadedPath = project_image_upload($_FILES[$fileKey]);
                        $values[$name] = $uploadedPath;
                    } catch (Throwable $e) {
                        $errors[$name] = 'Photo upload error: ' . $e->getMessage();
                    }
                } else {
                    $val = trim((string) ($_POST[$name] ?? ''));
                    $values[$name] = $val !== '' ? $val : null;
                }
            } elseif ($kind === 'select') {
                $val = trim((string) ($_POST[$name] ?? ''));
                $allowed = (array) $constraint;
                if (!in_array($val, $allowed, true)) {
                    $val = $allowed[0] ?? '';
                }
                $values[$name] = $val;
            } else {
                $val = trim((string) ($_POST[$name] ?? ''));
                if ($required && $val === '') {
                    $errors[$name] = $label . ' is required.';
                } elseif (is_int($constraint) && $constraint > 0 && mb_strlen($val) > $constraint) {
                    $errors[$name] = $label . ' must be ' . $constraint . ' characters or fewer.';
                } else {
                    $values[$name] = $val !== '' ? $val : null;
                }
            }
        }

        if ($type === 'blog_posts' && !isset($values['published_at'])) {
            if (($values['status'] ?? '') === 'published') {
                $values['published_at'] = date('Y-m-d H:i:s');
            }
        }

        if ($errors === []) {
            try {
                if ($postedId !== null) {
                    $setClauses = [];
                    $params = [':id' => $postedId];
                    foreach ($values as $col => $val) {
                        $setClauses[] = "`{$col}` = :{$col}";
                        $params[":{$col}"] = $val;
                    }
                    $sql = 'UPDATE ' . $resource['table'] . ' SET ' . implode(', ', $setClauses) . ' WHERE id = :id';
                    $stmt = $db->prepare($sql);
                    $stmt->execute($params);
                    add_flash_message('success', $resource['title'] . ' updated successfully.');
                } else {
                    $cols = array_keys($values);
                    $placeholders = array_map(fn($c) => ":{$c}", $cols);
                    $params = [];
                    foreach ($values as $col => $val) {
                        $params[":{$col}"] = $val;
                    }
                    $sql = 'INSERT INTO ' . $resource['table'] . ' (`' . implode('`, `', $cols) . '`) VALUES (' . implode(', ', $placeholders) . ')';
                    $stmt = $db->prepare($sql);
                    $stmt->execute($params);
                    add_flash_message('success', $resource['title'] . ' created successfully.');
                }
                admin_redirect('manage.php?type=' . urlencode($type));
            } catch (Throwable $e) {
                error_log('Failed to save ' . $type . ': ' . $e->getMessage());
                $errors['general'] = 'The record could not be saved. Please check the values and try again.';
            }
        }
    }
}

// Fetch single record if editing
$record = [];
if ($recordId !== null) {
    try {
        $stmt = $db->prepare('SELECT * FROM ' . $resource['table'] . ' WHERE id = :id LIMIT 1');
        $stmt->execute(['id' => $recordId]);
        $record = $stmt->fetch() ?: [];
        if ($record === []) {
            http_response_code(404);
            exit('Record not found.');
        }
    } catch (Throwable $e) {
        http_response_code(503);
        exit('Database error.');
    }
}

// Fetch list of records
$rows = [];
try {
    $orderBy = $resource['order_by'] ?? 'id DESC';
    $listStmt = $db->query('SELECT * FROM ' . $resource['table'] . ' ORDER BY ' . $orderBy . ' LIMIT 100');
    $rows = $listStmt->fetchAll() ?: [];
} catch (Throwable $e) {
    error_log('Failed to fetch ' . $type . ' list: ' . $e->getMessage());
}

require_once __DIR__ . '/_layout.php';
admin_start($resource['title']);
?>

<div class="admin-manage-container">
    <?php if ($recordId !== null || $isNew || ($errors !== [] && isset($_POST['action']) && $_POST['action'] === 'save')): ?>
        <?php
        $formData = array_merge($record, $_POST);
        $editing = $recordId !== null;
        ?>
        <section class="admin-panel admin-editor">
            <div class="admin-panel__heading">
                <div>
                    <h2><?= $editing ? 'Edit ' . e($resource['title']) . ' #' . $recordId : 'New ' . e($resource['title']) ?></h2>
                    <span class="admin-panel__intro">Complete the form details below.</span>
                </div>
                <a href="/admin/manage.php?type=<?= e($type) ?>" class="admin-button admin-button--small">← Back to list</a>
            </div>

            <?php if ($errors !== []): ?>
                <div class="admin-alert admin-alert--error" role="alert">
                    <strong>Please correct the following:</strong>
                    <ul style="margin: 6px 0 0 18px; padding: 0;">
                        <?php foreach ($errors as $err): ?>
                            <li><?= e($err) ?></li>
                        <?php endforeach; ?>
                    </ul>
                </div>
            <?php endif; ?>

            <form class="admin-form" method="post" enctype="multipart/form-data" action="/admin/manage.php?type=<?= e($type) ?><?= $editing ? '&amp;id=' . $recordId : '&amp;new=1' ?>">
                <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                <input type="hidden" name="type" value="<?= e($type) ?>">
                <input type="hidden" name="action" value="save">
                <?php if ($editing): ?>
                    <input type="hidden" name="id" value="<?= $recordId ?>">
                <?php endif; ?>

                <?php foreach ($resource['fields'] as $name => [$label, $kind, $required, $constraint]): ?>
                    <?php
                    $val = $formData[$name] ?? '';
                    $fieldId = 'field-' . $name;
                    ?>
                    <div class="admin-field<?= $kind === 'textarea' ? ' admin-field--wide' : '' ?>">
                        <?php if ($kind === 'checkbox'): ?>
                            <label class="admin-check">
                                <input id="<?= e($fieldId) ?>" name="<?= e($name) ?>" type="checkbox" value="1" <?= (int) $val === 1 ? 'checked' : '' ?>>
                                <span><?= e($label) ?></span>
                            </label>
                        <?php elseif ($kind === 'textarea'): ?>
                            <label for="<?= e($fieldId) ?>"><?= e($label) ?><?= $required ? ' *' : '' ?></label>
                            <textarea id="<?= e($fieldId) ?>" name="<?= e($name) ?>" rows="5" <?= $required ? 'required' : '' ?>><?= e((string) $val) ?></textarea>
                        <?php elseif ($kind === 'image'): ?>
                            <label for="<?= e($fieldId) ?>"><?= e($label) ?><?= $required ? ' *' : '' ?></label>
                            
                            <?php if (!empty($val)): ?>
                                <div id="preview-wrap-<?= e($name) ?>" style="margin: 6px 0 10px; display: flex; align-items: center; gap: 12px; padding: 10px; background: #fafbfa; border: 1px solid var(--admin-line); border-radius: 6px;">
                                    <img id="img-preview-<?= e($name) ?>" src="<?= e(asset((string) $val)) ?>" alt="Current preview" style="max-height: 80px; max-width: 140px; border-radius: 4px; object-fit: cover; border: 1px solid var(--admin-line);">
                                    <div>
                                        <small style="color: var(--admin-muted); display: block;">Current photo:</small>
                                        <code style="font-size: 12px; word-break: break-all;"><?= e((string) $val) ?></code>
                                    </div>
                                </div>
                            <?php endif; ?>

                            <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 8px; flex-wrap: wrap;">
                                <input type="file" id="file-<?= e($name) ?>" name="<?= e($name) ?>_file" accept="image/jpeg,image/png,image/webp,image/gif" style="display: none;" onchange="handleImageFileSelect(this, '<?= e($name) ?>')">
                                <button type="button" class="admin-button admin-button--primary" onclick="document.getElementById('file-<?= e($name) ?>').click();" style="display: inline-flex; align-items: center; gap: 6px; cursor: pointer;">
                                    📁 Upload Photo from PC
                                </button>
                                <span id="file-name-<?= e($name) ?>" style="font-size: 13px; color: var(--admin-muted);">No new file chosen</span>
                            </div>

                            <input id="<?= e($fieldId) ?>" name="<?= e($name) ?>" type="text" value="<?= e((string) $val) ?>" placeholder="Or enter image path, e.g. uploads/... or images/...">
                            <small style="color: var(--admin-muted); display: block; margin-top: 4px;">Click the button above to upload a photo directly from your computer, or enter an image path.</small>
                        <?php elseif ($kind === 'select'): ?>
                            <label for="<?= e($fieldId) ?>"><?= e($label) ?><?= $required ? ' *' : '' ?></label>
                            <select id="<?= e($fieldId) ?>" name="<?= e($name) ?>" <?= $required ? 'required' : '' ?>>
                                <?php foreach ((array) $constraint as $opt): ?>
                                    <option value="<?= e($opt) ?>" <?= (string) $val === (string) $opt ? 'selected' : '' ?>><?= e(ucfirst(str_replace('_', ' ', (string) $opt))) ?></option>
                                <?php endforeach; ?>
                            </select>
                        <?php elseif ($kind === 'category_select'): ?>
                            <label for="<?= e($fieldId) ?>"><?= e($label) ?></label>
                            <select id="<?= e($fieldId) ?>" name="<?= e($name) ?>">
                                <option value="">-- None / Uncategorized --</option>
                                <?php foreach ($blogCategories as $cat): ?>
                                    <option value="<?= (int) $cat['id'] ?>" <?= (string) $val === (string) $cat['id'] ? 'selected' : '' ?>><?= e($cat['name']) ?></option>
                                <?php endforeach; ?>
                            </select>
                        <?php elseif ($kind === 'date'): ?>
                            <label for="<?= e($fieldId) ?>"><?= e($label) ?><?= $required ? ' *' : '' ?></label>
                            <input id="<?= e($fieldId) ?>" name="<?= e($name) ?>" type="date" value="<?= e((string) $val) ?>" <?= $required ? 'required' : '' ?>>
                        <?php elseif ($kind === 'number'): ?>
                            <label for="<?= e($fieldId) ?>"><?= e($label) ?><?= $required ? ' *' : '' ?></label>
                            <input id="<?= e($fieldId) ?>" name="<?= e($name) ?>" type="number" step="any" value="<?= e((string) $val) ?>" <?= $required ? 'required' : '' ?>>
                        <?php else: ?>
                            <label for="<?= e($fieldId) ?>"><?= e($label) ?><?= $required ? ' *' : '' ?></label>
                            <input id="<?= e($fieldId) ?>" name="<?= e($name) ?>" type="text" value="<?= e((string) $val) ?>" <?= $required ? 'required' : '' ?> <?= is_int($constraint) && $constraint > 0 ? 'maxlength="' . $constraint . '"' : '' ?>>
                        <?php endif; ?>

                        <?php if (isset($errors[$name])): ?>
                            <small class="admin-field__error"><?= e($errors[$name]) ?></small>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>

                <div class="admin-field admin-field--wide" style="display: flex; gap: 12px; margin-top: 14px;">
                    <button class="admin-button admin-button--primary" type="submit"><?= $editing ? 'Save Changes' : 'Create Record' ?></button>
                    <a href="/admin/manage.php?type=<?= e($type) ?>" class="admin-button">Cancel</a>
                </div>
            </form>
        </section>
    <?php else: ?>
        <div class="admin-toolbar" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
            <div>
                <p style="margin: 0; font-weight: 600; font-size: 15px;"><?= e($resource['title']) ?></p>
                <span style="color: var(--admin-muted); font-size: 13px;">Manage company <?= strtolower(e($resource['title'])) ?> records.</span>
            </div>
            <div>
                <a class="admin-button admin-button--primary" href="/admin/manage.php?type=<?= e($type) ?>&amp;new=1">+ Add New <?= e($resource['title']) ?></a>
            </div>
        </div>

        <section class="admin-panel admin-table-wrap">
            <?php if ($rows === []): ?>
                <div style="text-align: center; padding: 48px 24px;">
                    <h3 style="margin: 0 0 8px; font-size: 16px;">No <?= strtolower(e($resource['title'])) ?> found</h3>
                    <p style="margin: 0 0 16px; color: var(--admin-muted); font-size: 13px;">Create the first record to get started.</p>
                    <a class="admin-button admin-button--primary" href="/admin/manage.php?type=<?= e($type) ?>&amp;new=1">+ Add <?= e($resource['title']) ?></a>
                </div>
            <?php else: ?>
                <table class="admin-table">
                    <thead>
                        <tr>
                            <th scope="col" style="width: 50px;">#</th>
                            <?php foreach ($resource['columns'] as $col): ?>
                                <th scope="col"><?= e(ucwords(str_replace('_', ' ', $col))) ?></th>
                            <?php endforeach; ?>
                            <th scope="col" style="text-align: right;">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($rows as $row): ?>
                            <tr>
                                <td><?= (int) $row['id'] ?></td>
                                <?php foreach ($resource['columns'] as $col): ?>
                                    <td>
                                        <?php
                                        $val = $row[$col] ?? '';
                                        if (in_array($col, ['is_published', 'is_featured', 'is_demo'], true)) {
                                            echo (int) $val === 1 ? '<span style="color: #185a2d; font-weight: 600;">Yes</span>' : '<span style="color: var(--admin-muted);">No</span>';
                                        } elseif (in_array($col, ['status'], true)) {
                                            echo '<span style="display: inline-block; padding: 2px 7px; border-radius: 4px; font-size: 11px; font-weight: 700; background: #e9ece9;">' . e(ucfirst((string) $val)) . '</span>';
                                        } else {
                                            echo e(mb_strimwidth((string) $val, 0, 50, '...'));
                                        }
                                        ?>
                                    </td>
                                <?php endforeach; ?>
                                <td style="text-align: right;">
                                    <div class="admin-row-actions" style="display: inline-flex; gap: 8px;">
                                        <a class="admin-button admin-button--small" href="/admin/manage.php?type=<?= e($type) ?>&amp;id=<?= (int) $row['id'] ?>">Edit</a>
                                        <form method="post" action="/admin/manage.php?type=<?= e($type) ?>" onsubmit="return confirm('Are you sure you want to delete this record?');" style="margin: 0; display: inline;">
                                            <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
                                            <input type="hidden" name="type" value="<?= e($type) ?>">
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

<script>
function handleImageFileSelect(input, fieldName) {
    if (!input.files || !input.files[0]) return;
    const file = input.files[0];
    const nameEl = document.getElementById('file-name-' + fieldName);
    if (nameEl) {
        nameEl.textContent = 'Selected: ' + file.name + ' (' + (file.size / 1024).toFixed(1) + ' KB)';
        nameEl.style.color = '#185a2d';
        nameEl.style.fontWeight = 'bold';
    }
    const reader = new FileReader();
    reader.onload = function(e) {
        let preview = document.getElementById('img-preview-' + fieldName);
        if (!preview) {
            const wrap = document.createElement('div');
            wrap.id = 'preview-wrap-' + fieldName;
            wrap.style.cssText = 'margin: 6px 0 10px; display: flex; align-items: center; gap: 12px; padding: 10px; background: #fafbfa; border: 1px solid var(--admin-line); border-radius: 6px;';
            preview = document.createElement('img');
            preview.id = 'img-preview-' + fieldName;
            preview.style.cssText = 'max-height: 80px; max-width: 140px; border-radius: 4px; object-fit: cover; border: 1px solid var(--admin-line);';
            const labelDiv = document.createElement('div');
            labelDiv.innerHTML = '<small style="color: var(--admin-muted); display: block;">New photo selected:</small><code style="font-size: 12px;">' + file.name + '</code>';
            wrap.appendChild(preview);
            wrap.appendChild(labelDiv);
            const fieldParent = input.closest('.admin-field');
            fieldParent.insertBefore(wrap, fieldParent.children[1] || null);
        }
        preview.src = e.target.result;
    };
    reader.readAsDataURL(file);
}
</script>

<?php admin_end(); ?>
