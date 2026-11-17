<?php

declare(strict_types=1);

$companyName = company_setting('company_name');
$pageTitleText = trim((string) ($pageTitle ?? ''));
$pageTitleText = preg_replace('/\s*\|\s*ICON Construction Company$/', '', $pageTitleText);
$pageTitle = $pageTitleText !== '' ? $pageTitleText . ' | ' . $companyName : $companyName . ' | Built with purpose';
$pageDescription = $pageDescription ?? company_setting('company_description');
$faviconHref = company_asset_href('company_favicon');
$contentVersion = '';

if (
    getenv('DB_HOST') !== false
    && getenv('DB_NAME') !== false
    && getenv('DB_USER') !== false
    && getenv('DB_PASSWORD') !== false
) {
    try {
        $contentVersion = public_content_version();
    } catch (PDOException | RuntimeException | JsonException $error) {
        error_log('ICON public content version query failed: ' . $error->getMessage());
    }
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="<?= e($pageDescription) ?>">
    <meta name="theme-color" content="#17251f">
    <title><?= e($pageTitle) ?></title>
    <link rel="icon" href="<?= e($faviconHref) ?>">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="<?= e(asset('css/styles.css')) ?>">
    <script>
        document.documentElement.classList.add('js');
    </script>
    <script src="<?= e(asset('js/main.js')) ?>" defer></script>
    <?= $pageExtraHeadTags ?? '' ?>
</head>
<body data-content-version="<?= e($contentVersion) ?>">
<a class="skip-link" href="#main-content">Skip to content</a>
<?php $demoNotice = company_demo_notice(); ?>
<?php if ($demoNotice !== ''): ?>
    <aside class="sample-notice" role="note"><?= e($demoNotice) ?></aside>
<?php endif; ?>
<?php require PROJECT_ROOT . '/includes/navigation.php'; ?>
