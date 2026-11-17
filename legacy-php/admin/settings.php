<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';
require_admin_role(['admin']);

$settingFields = [
    'company_demo_notice' => ['Public sample/demo notice (clear it after replacing sample content with verified details)', 'textarea', 500],
    'company_name' => ['Company name', 'text', 160],
    'company_tagline' => ['Company tagline', 'text', 220],
    'company_description' => ['Company description', 'textarea', 2000],
    'company_hero_heading' => ['Homepage hero headline', 'text', 220],
    'company_hero_subheading' => ['Homepage hero introduction', 'textarea', 500],
    'company_service_area' => ['Service area description', 'text', 220],
    'company_phone' => ['Phone number', 'text', 40],
    'company_whatsapp' => ['WhatsApp number (blank uses phone)', 'text', 40],
    'company_email' => ['Email address', 'email', 190],
    'company_address' => ['Physical address', 'textarea', 500],
    'company_google_maps_location' => ['Google Maps URL or location', 'text', 1000],
    'company_business_hours' => ['Business hours', 'textarea', 1000],
    'company_facebook_url' => ['Facebook URL', 'url', 500],
    'company_instagram_url' => ['Instagram URL', 'url', 500],
    'company_linkedin_url' => ['LinkedIn URL', 'url', 500],
];
$processFields = [];
for ($step = 1; $step <= 8; $step++) {
    $processFields['company_process_' . $step . '_title'] = ['Process step ' . $step . ' title', 'text', 100];
    $processFields['company_process_' . $step . '_description'] = ['Process step ' . $step . ' description', 'textarea', 500];
}
$settingFields = array_merge($settingFields, $processFields);
$mediaFields = [
    'company_logo' => ['Logo', 'image/png,image/jpeg,image/webp', ['image/png' => 'png', 'image/jpeg' => 'jpg', 'image/webp' => 'webp']],
    'company_favicon' => ['Favicon', 'image/png,image/x-icon,image/vnd.microsoft.icon', ['image/png' => 'png', 'image/x-icon' => 'ico', 'image/vnd.microsoft.icon' => 'ico']],
    'company_hero_image' => ['Hero image (fallback)', 'image/jpeg,image/png,image/webp', ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp']],
    'company_hero_image_1' => ['Homepage hero slide 1', 'image/jpeg,image/png,image/webp', ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp']],
    'company_hero_image_2' => ['Homepage hero slide 2', 'image/jpeg,image/png,image/webp', ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp']],
    'company_hero_image_3' => ['Homepage hero slide 3', 'image/jpeg,image/png,image/webp', ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp']],
    'company_hero_image_4' => ['Homepage hero slide 4', 'image/jpeg,image/png,image/webp', ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp']],
];
$settingFields['company_hero_image_1_alt'] = ['Hero slide 1 alt text', 'text', 255];
$settingFields['company_hero_image_2_alt'] = ['Hero slide 2 alt text', 'text', 255];
$settingFields['company_hero_image_3_alt'] = ['Hero slide 3 alt text', 'text', 255];
$settingFields['company_hero_image_4_alt'] = ['Hero slide 4 alt text', 'text', 255];
$settingDefaults = company_settings();
$settings = $settingDefaults;
$errors = [];
$newFiles = [];
$oldFiles = [];
$originalMediaValues = [];

try {
    $currentQuery = db()->prepare('SELECT setting_key, setting_value FROM company_settings');
    $currentQuery->execute();
    foreach ($currentQuery->fetchAll() as $row) {
        if (array_key_exists($row['setting_key'], $settingDefaults)) {
            $value = trim((string) $row['setting_value']);
            if ($value !== '' || $row['setting_key'] === 'company_demo_notice') {
                $settings[$row['setting_key']] = $value;
            }
        }
    }
    foreach ($mediaFields as $key => $_field) {
        $originalMediaValues[$key] = $settings[$key];
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (!admin_post_token_is_valid()) {
            http_response_code(400);
            exit('The request could not be verified. Reload the page and try again.');
        }

        foreach ($settingFields as $key => [$label, $type, $maxLength]) {
            $settings[$key] = admin_input_string($_POST, $key);
            if (strlen($settings[$key]) > $maxLength) {
                $errors[$key] = $label . ' must be ' . $maxLength . ' characters or fewer.';
            }
        }

        if ($settings['company_name'] === '') {
            $errors['company_name'] = 'Company name is required.';
        }

        if ($settings['company_email'] !== '' && filter_var($settings['company_email'], FILTER_VALIDATE_EMAIL) === false) {
            $errors['company_email'] = 'Enter a valid email address.';
        }

        foreach (['company_phone', 'company_whatsapp'] as $key) {
            if ($settings[$key] !== '' && !preg_match('/^[+0-9().\s-]{7,40}$/', $settings[$key])) {
                $errors[$key] = 'Enter a valid contact number.';
            }
        }

        $allowedSocialHosts = [
            'company_facebook_url' => ['facebook.com', 'www.facebook.com', 'm.facebook.com'],
            'company_instagram_url' => ['instagram.com', 'www.instagram.com'],
            'company_linkedin_url' => ['linkedin.com', 'www.linkedin.com'],
        ];
        foreach ($allowedSocialHosts as $key => $hosts) {
            if ($settings[$key] === '') {
                continue;
            }

            $host = strtolower((string) parse_url($settings[$key], PHP_URL_HOST));
            if (
                filter_var($settings[$key], FILTER_VALIDATE_URL) === false
                || strtolower((string) parse_url($settings[$key], PHP_URL_SCHEME)) !== 'https'
                || !in_array($host, $hosts, true)
            ) {
                $errors[$key] = 'Enter a valid HTTPS URL for the matching social network.';
            }
        }

        if ($settings['company_google_maps_location'] !== '' && filter_var($settings['company_google_maps_location'], FILTER_VALIDATE_URL) !== false) {
            $mapsHost = strtolower((string) parse_url($settings['company_google_maps_location'], PHP_URL_HOST));
            if (
                strtolower((string) parse_url($settings['company_google_maps_location'], PHP_URL_SCHEME)) !== 'https'
                || !in_array($mapsHost, ['google.com', 'www.google.com', 'maps.google.com', 'maps.app.goo.gl', 'goo.gl'], true)
            ) {
                $errors['company_google_maps_location'] = 'Use a Google Maps HTTPS link or enter a location name or address.';
            }
        }

        foreach ($mediaFields as $key => [$label, $_accept, $mimeTypes]) {
            $file = $_FILES[$key] ?? null;
            if (!is_array($file) || ($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
                continue;
            }
            if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK || !is_string($file['tmp_name'] ?? null)) {
                $errors[$key] = $label . ' could not be uploaded.';
                continue;
            }
            if ((int) ($file['size'] ?? 0) > 5 * 1024 * 1024) {
                $errors[$key] = $label . ' must be 5 MB or smaller.';
                continue;
            }

            $imageInfo = @getimagesize($file['tmp_name']);
            $mime = is_array($imageInfo) ? ($imageInfo['mime'] ?? '') : '';
            $fileInfo = new finfo(FILEINFO_MIME_TYPE);
            $detectedMime = $fileInfo->file($file['tmp_name']);
            if (
                !isset($mimeTypes[$mime])
                || !in_array($detectedMime, [$mime, 'application/octet-stream'], true)
                || !is_array($imageInfo)
                || $imageInfo[0] > 12000
                || $imageInfo[1] > 12000
            ) {
                $errors[$key] = $label . ' must be a valid supported image file.';
                continue;
            }

            $filename = bin2hex(random_bytes(16)) . '.' . $mimeTypes[$mime];
            $destination = PROJECT_ROOT . '/assets/uploads/' . $filename;
            if (!move_uploaded_file($file['tmp_name'], $destination)) {
                $errors[$key] = $label . ' could not be saved. Check upload directory permissions.';
                continue;
            }

            $newFiles[] = $destination;
            $newValue = 'uploads/' . $filename;
            $oldValue = $settings[$key];
            if (preg_match('/^uploads\/[a-f0-9]{32}\.(?:jpg|png|webp|ico)$/', $oldValue)) {
                $oldFiles[] = PROJECT_ROOT . '/assets/' . $oldValue;
            }
            $settings[$key] = $newValue;
        }

        if ($errors === []) {
            $connection = db();
            $connection->beginTransaction();
            try {
                $save = $connection->prepare(
                    'INSERT INTO company_settings (setting_key, setting_value, is_public)
                    VALUES (:setting_key, :setting_value, 1)
                    ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), is_public = 1'
                );
                foreach (array_merge($settingFields, $mediaFields) as $key => $_field) {
                    $save->execute(['setting_key' => $key, 'setting_value' => $settings[$key]]);
                }
                $connection->commit();
            } catch (PDOException $error) {
                if ($connection->inTransaction()) {
                    $connection->rollBack();
                }
                throw $error;
            }

            foreach (array_unique($oldFiles) as $oldFile) {
                if (is_file($oldFile) && !unlink($oldFile)) {
                    error_log('ICON company media file could not be removed: ' . $oldFile);
                }
            }
            add_flash_message('success', 'Company settings updated.');
            admin_redirect('settings.php');
        }

        if ($newFiles !== []) {
            foreach ($newFiles as $newFile) {
                if (is_file($newFile) && !unlink($newFile)) {
                    error_log('ICON rejected company media file could not be removed: ' . $newFile);
                }
            }
            foreach ($originalMediaValues as $key => $originalValue) {
                $settings[$key] = $originalValue;
            }
        }
    }
} catch (PDOException | RuntimeException $error) {
    foreach ($newFiles as $newFile) {
        if (is_file($newFile)) {
            unlink($newFile);
        }
    }
    error_log('ICON company settings update failed: ' . $error->getMessage());
    http_response_code(503);
    exit('Company settings are temporarily unavailable.');
}

require_once __DIR__ . '/_layout.php';
admin_start('Company settings');
?>
<section class="admin-panel admin-editor">
    <p class="admin-panel__intro">Public contact, branding and social details are shared across the website. Keep the sample/demo notice visible until all sample company and service information has been replaced with verified details. Uploaded images must be PNG, JPEG, WebP or ICO as applicable, and no larger than 5 MB.</p>
    <?php if ($errors !== []): ?><div class="admin-alert admin-alert--error" role="alert"><?php foreach ($errors as $error): ?><div><?= e($error) ?></div><?php endforeach; ?></div><?php endif; ?>
    <form class="admin-form admin-form--single" method="post" enctype="multipart/form-data" action="/admin/settings.php">
        <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
        <?php foreach ($settingFields as $key => [$label, $type, $maxLength]): ?>
            <div class="admin-field">
                <label for="<?= e($key) ?>"><?= e($label) ?></label>
                <?php if ($type === 'textarea'): ?>
                    <textarea id="<?= e($key) ?>" name="<?= e($key) ?>" maxlength="<?= $maxLength ?>"><?= e($settings[$key]) ?></textarea>
                <?php else: ?>
                    <input id="<?= e($key) ?>" name="<?= e($key) ?>" value="<?= e($settings[$key]) ?>" maxlength="<?= $maxLength ?>" type="<?= e($type) ?>" <?= $key === 'company_name' ? 'required' : '' ?>>
                <?php endif; ?>
                <?php if (isset($errors[$key])): ?><small class="admin-field__error"><?= e($errors[$key]) ?></small><?php endif; ?>
            </div>
        <?php endforeach; ?>

        <?php foreach ($mediaFields as $key => [$label, $accept, $_mimeTypes]): ?>
            <div class="admin-field admin-media-field">
                <label for="<?= e($key) ?>"><?= e($label) ?></label>
                <img class="admin-media-preview admin-media-preview--<?= e($key) ?>" src="<?= e(company_asset_href($key)) ?>" alt="Current <?= e(strtolower($label)) ?> preview">
                <input id="<?= e($key) ?>" name="<?= e($key) ?>" type="file" accept="<?= e($accept) ?>">
                <small class="admin-field__hint">Current image: <?= e(basename($settings[$key])) ?>. Leave empty to keep it.</small>
                <?php if (isset($errors[$key])): ?><small class="admin-field__error"><?= e($errors[$key]) ?></small><?php endif; ?>
            </div>
        <?php endforeach; ?>

        <div class="admin-field"><button class="admin-button admin-button--primary" type="submit">Save company settings</button></div>
    </form>
</section>
<?php admin_end(); ?>
