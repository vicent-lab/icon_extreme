<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$projectRoot = dirname(__DIR__);
$sources = [
    'workers' => $projectRoot . '/assets/images/hero-construction.jpg',
    'building' => $projectRoot . '/assets/images/project-building.jpg',
    'planning' => $projectRoot . '/assets/images/project-planning.jpg',
];
$variants = [
    ['site-construction-workers', 'workers', 0.42, 0.56, 1.10, 'Construction workers coordinating tasks on a building site'],
    ['site-engineers-supervision', 'workers', 0.60, 0.48, 1.42, 'Engineers and supervisors reviewing progress on site'],
    ['site-equipment', 'workers', 0.30, 0.62, 1.58, 'Construction equipment and materials at a work site'],
    ['safety-ppe', 'workers', 0.54, 0.44, 1.72, 'Workers wearing helmets and personal protective equipment'],
    ['safety-inspection', 'workers', 0.68, 0.58, 1.86, 'Site inspection and safety supervision in progress'],
    ['completed-residential', 'building', 0.46, 0.52, 1.08, 'Completed residential building exterior'],
    ['completed-commercial', 'building', 0.62, 0.46, 1.26, 'Completed commercial building facade'],
    ['process-consultation', 'planning', 0.50, 0.52, 1.00, 'Consultation with project drawings and plans'],
    ['process-site-assessment', 'workers', 0.48, 0.66, 1.34, 'Site assessment with workers reviewing conditions'],
    ['process-planning', 'planning', 0.36, 0.48, 1.18, 'Planning and design review with construction drawings'],
    ['process-cost-estimation', 'planning', 0.66, 0.54, 1.34, 'Cost estimation discussion using project plans'],
    ['process-construction', 'workers', 0.38, 0.52, 1.22, 'Construction work progressing on site'],
    ['process-quality-inspection', 'building', 0.54, 0.58, 1.44, 'Quality inspection of building finishes'],
    ['process-handover', 'building', 0.42, 0.48, 1.62, 'Completed building prepared for handover'],
    ['service-building-construction', 'building', 0.48, 0.50, 1.04, 'Building construction service example'],
    ['service-residential', 'building', 0.58, 0.56, 1.38, 'Residential construction project example'],
    ['service-commercial', 'building', 0.64, 0.44, 1.12, 'Commercial construction project example'],
    ['service-road-civil', 'workers', 0.44, 0.68, 1.48, 'Road and civil works coordination on site'],
    ['service-roofing', 'building', 0.40, 0.36, 1.56, 'Roofing and exterior construction detail'],
    ['service-concrete', 'workers', 0.52, 0.60, 1.66, 'Concrete works and site preparation'],
    ['service-plumbing', 'planning', 0.44, 0.60, 1.48, 'Plumbing planning and installation coordination'],
    ['service-electrical', 'planning', 0.60, 0.44, 1.52, 'Electrical installation planning and drawings'],
    ['service-renovation', 'planning', 0.34, 0.54, 1.40, 'Renovation planning with building drawings'],
    ['service-painting', 'building', 0.52, 0.46, 1.70, 'Painting and finishing work on a building'],
    ['service-site-preparation', 'workers', 0.36, 0.58, 1.18, 'Site preparation and groundwork coordination'],
    ['service-civil-works', 'workers', 0.58, 0.64, 1.54, 'Civil works and infrastructure coordination'],
];
$outputDirectory = $projectRoot . '/assets/images/site';
$thumbnailDirectory = $outputDirectory . '/thumbs';

if (!function_exists('imagewebp') || !function_exists('imagecreatefromjpeg')) {
    fwrite(STDERR, "GD with WebP and JPEG support is required.\n");
    exit(1);
}
foreach ([$outputDirectory, $thumbnailDirectory] as $directory) {
    if (!is_dir($directory) && !mkdir($directory, 0755, true) && !is_dir($directory)) {
        fwrite(STDERR, "Could not create the site imagery directory.\n");
        exit(1);
    }
}

$loadedSources = [];
foreach ($sources as $name => $path) {
    $image = is_file($path) ? @imagecreatefromjpeg($path) : false;
    if ($image === false) {
        fwrite(STDERR, "Could not load the sample image: {$path}\n");
        exit(1);
    }
    $loadedSources[$name] = $image;
}

$manifest = [];
foreach ($variants as [$filename, $sourceName, $focusX, $focusY, $zoom]) {
    $source = $loadedSources[$sourceName];
    $sourceWidth = imagesx($source);
    $sourceHeight = imagesy($source);
    $baseWidth = min($sourceWidth, $sourceHeight * 1.5);
    $cropWidth = $baseWidth / $zoom;
    $cropHeight = $cropWidth / 1.5;
    $sourceX = max(0, min($sourceWidth - $cropWidth, $sourceWidth * $focusX - $cropWidth / 2));
    $sourceY = max(0, min($sourceHeight - $cropHeight, $sourceHeight * $focusY - $cropHeight / 2));
    $canvas = imagecreatetruecolor(1200, 800);
    imagecopyresampled($canvas, $source, 0, 0, (int) round($sourceX), (int) round($sourceY), 1200, 800, (int) round($cropWidth), (int) round($cropHeight));
    $path = $outputDirectory . '/' . $filename . '.webp';
    imagewebp($canvas, $path, 80);
    $thumb = imagecreatetruecolor(600, 400);
    imagecopyresampled($thumb, $canvas, 0, 0, 0, 0, 600, 400, 1200, 800);
    imagewebp($thumb, $thumbnailDirectory . '/' . $filename . '.webp', 74);
    imagedestroy($thumb);
    imagedestroy($canvas);
    $manifest[] = $filename;
}

foreach ($loadedSources as $source) {
    imagedestroy($source);
}

printf("Generated %d optimized site images in %s\n", count($manifest), $outputDirectory);
