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
    ['site-preparation', 0.34, 0.64, 1.08, 'workers'],
    ['foundation-excavation', 0.62, 0.70, 1.28, 'workers'],
    ['foundation-works', 0.48, 0.58, 1.46, 'workers'],
    ['reinforcement', 0.28, 0.46, 1.62, 'workers'],
    ['concrete-foundation', 0.56, 0.50, 1.78, 'workers'],
    ['wall-construction', 0.44, 0.44, 1.10, 'building'],
    ['structural-works', 0.66, 0.52, 1.24, 'building'],
    ['roofing-stage', 0.38, 0.38, 1.42, 'building'],
    ['plumbing-installation', 0.58, 0.62, 1.58, 'building'],
    ['electrical-installation', 0.46, 0.56, 1.74, 'building'],
    ['plastering', 0.52, 0.50, 1.06, 'planning'],
    ['flooring', 0.36, 0.56, 1.20, 'planning'],
    ['painting-finishing', 0.68, 0.48, 1.36, 'planning'],
    ['exterior-finishing', 0.44, 0.42, 1.52, 'planning'],
    ['interior-finishing', 0.56, 0.58, 1.68, 'planning'],
    ['landscaping', 0.40, 0.66, 1.84, 'workers'],
    ['final-inspection', 0.60, 0.46, 1.92, 'building'],
    ['completed-building', 0.50, 0.52, 1.00, 'building'],
];
$outputDirectory = $projectRoot . '/assets/images/demo-gallery';
$thumbnailDirectory = $outputDirectory . '/thumbs';

if (!function_exists('imagewebp') || !function_exists('imagecreatefromjpeg')) {
    fwrite(STDERR, "GD with WebP and JPEG support is required.\n");
    exit(1);
}
foreach ([$outputDirectory, $thumbnailDirectory] as $directory) {
    if (!is_dir($directory) && !mkdir($directory, 0755, true) && !is_dir($directory)) {
        fwrite(STDERR, "Could not create the demo gallery directory.\n");
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

foreach ($variants as $index => [$filename, $focusX, $focusY, $zoom, $sourceName]) {
    $source = $loadedSources[$sourceName];
    $sourceWidth = imagesx($source);
    $sourceHeight = imagesy($source);
    $baseWidth = min($sourceWidth, $sourceHeight * 1.6);
    $cropWidth = $baseWidth / $zoom;
    $cropHeight = $cropWidth / 1.6;
    $sourceX = max(0, min($sourceWidth - $cropWidth, $sourceWidth * $focusX - $cropWidth / 2));
    $sourceY = max(0, min($sourceHeight - $cropHeight, $sourceHeight * $focusY - $cropHeight / 2));
    $canvas = imagecreatetruecolor(1280, 800);
    imagecopyresampled(
        $canvas,
        $source,
        0,
        0,
        (int) round($sourceX),
        (int) round($sourceY),
        1280,
        800,
        (int) round($cropWidth),
        (int) round($cropHeight)
    );

    $path = sprintf('%s/%02d-%s.webp', $outputDirectory, $index + 1, $filename);
    if (!imagewebp($canvas, $path, 80)) {
        imagedestroy($canvas);
        fwrite(STDERR, "Could not write the demo image: {$path}\n");
        exit(1);
    }
    $thumbnail = imagecreatetruecolor(640, 400);
    imagecopyresampled($thumbnail, $canvas, 0, 0, 0, 0, 640, 400, 1280, 800);
    $thumbnailPath = sprintf('%s/%02d-%s.webp', $thumbnailDirectory, $index + 1, $filename);
    if (!imagewebp($thumbnail, $thumbnailPath, 74)) {
        imagedestroy($thumbnail);
        imagedestroy($canvas);
        fwrite(STDERR, "Could not write the demo thumbnail: {$thumbnailPath}\n");
        exit(1);
    }
    imagedestroy($thumbnail);
    imagedestroy($canvas);
}

foreach ($loadedSources as $source) {
    imagedestroy($source);
}

printf("Generated %d optimized sample gallery images in %s\n", count($variants), $outputDirectory);
