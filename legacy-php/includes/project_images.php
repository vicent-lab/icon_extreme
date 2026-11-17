<?php

declare(strict_types=1);

function project_image_upload(array $file): string
{
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK || !is_string($file['tmp_name'] ?? null)) {
        throw new InvalidArgumentException('Choose a valid image file.');
    }

    if ((int) ($file['size'] ?? 0) > 5 * 1024 * 1024) {
        throw new InvalidArgumentException('Images must be 5 MB or smaller.');
    }

    $imageInfo = @getimagesize($file['tmp_name']);
    $mime = is_array($imageInfo) ? ($imageInfo['mime'] ?? '') : '';
    $allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
    $width = is_array($imageInfo) ? (int) ($imageInfo[0] ?? 0) : 0;
    $height = is_array($imageInfo) ? (int) ($imageInfo[1] ?? 0) : 0;

    if (!in_array($mime, $allowedMimes, true) || $width < 1 || $height < 1) {
        throw new InvalidArgumentException('Upload a valid JPEG, PNG or WebP image.');
    }

    if ($width > 8000 || $height > 8000 || $width * $height > 30_000_000) {
        throw new InvalidArgumentException('Images must be no larger than 8000 × 8000 pixels or 30 megapixels.');
    }

    if (!function_exists('imagewebp') || !function_exists('imagecreatefromstring')) {
        throw new RuntimeException('GD with WebP support is required to optimize project images.');
    }

    $sourceBytes = file_get_contents($file['tmp_name']);
    $source = is_string($sourceBytes) ? @imagecreatefromstring($sourceBytes) : false;
    if ($source === false) {
        throw new InvalidArgumentException('The uploaded image could not be decoded.');
    }

    $filename = bin2hex(random_bytes(16));
    $uploadDirectory = PROJECT_ROOT . '/assets/uploads';
    $thumbnailDirectory = $uploadDirectory . '/thumbs';
    foreach ([$uploadDirectory, $thumbnailDirectory] as $directory) {
        if (!is_dir($directory) && !mkdir($directory, 0755, true) && !is_dir($directory)) {
            imagedestroy($source);
            throw new RuntimeException('The project image directory could not be created.');
        }
    }

    $imagePath = 'uploads/' . $filename . '.webp';
    $imageDestination = PROJECT_ROOT . '/assets/' . $imagePath;
    $thumbnailDestination = $thumbnailDirectory . '/' . $filename . '.webp';

    try {
        $maxWidth = 1920;
        $maxHeight = 1440;
        $scale = min(1, $maxWidth / imagesx($source), $maxHeight / imagesy($source));
        $resizedWidth = max(1, (int) round(imagesx($source) * $scale));
        $resizedHeight = max(1, (int) round(imagesy($source) * $scale));
        $resized = imagecreatetruecolor($resizedWidth, $resizedHeight);
        imagealphablending($resized, false);
        imagesavealpha($resized, true);
        imagecopyresampled(
            $resized,
            $source,
            0,
            0,
            0,
            0,
            $resizedWidth,
            $resizedHeight,
            imagesx($source),
            imagesy($source)
        );

        if (!imagewebp($resized, $imageDestination, 82)) {
            imagedestroy($resized);
            throw new RuntimeException('The optimized project image could not be saved.');
        }

        $thumbnailWidth = 640;
        $thumbnailHeight = 420;
        $cropScale = max($thumbnailWidth / imagesx($source), $thumbnailHeight / imagesy($source));
        $cropWidth = min(imagesx($source), (int) ceil($thumbnailWidth / $cropScale));
        $cropHeight = min(imagesy($source), (int) ceil($thumbnailHeight / $cropScale));
        $thumbnail = imagecreatetruecolor($thumbnailWidth, $thumbnailHeight);
        imagealphablending($thumbnail, false);
        imagesavealpha($thumbnail, true);
        imagecopyresampled(
            $thumbnail,
            $source,
            0,
            0,
            (int) floor((imagesx($source) - $cropWidth) / 2),
            (int) floor((imagesy($source) - $cropHeight) / 2),
            $thumbnailWidth,
            $thumbnailHeight,
            $cropWidth,
            $cropHeight
        );

        $thumbnailSaved = imagewebp($thumbnail, $thumbnailDestination, 78);
        imagedestroy($thumbnail);
        imagedestroy($resized);
        if (!$thumbnailSaved) {
            throw new RuntimeException('The project image thumbnail could not be saved.');
        }
    } catch (Throwable $error) {
        if (is_file($imageDestination)) {
            unlink($imageDestination);
        }
        if (is_file($thumbnailDestination)) {
            unlink($thumbnailDestination);
        }
        throw $error;
    } finally {
        imagedestroy($source);
    }

    return $imagePath;
}

function project_image_delete_files(string $path): void
{
    if (!preg_match('~^uploads/([a-f0-9]{32})\.(?:jpg|png|webp)$~D', $path, $matches)) {
        return;
    }

    $files = [PROJECT_ROOT . '/assets/' . $path];
    if (str_ends_with($path, '.webp')) {
        $files[] = PROJECT_ROOT . '/assets/uploads/thumbs/' . $matches[1] . '.webp';
    }

    foreach ($files as $file) {
        if (is_file($file) && !unlink($file)) {
            error_log('ICON project image file could not be removed: ' . $file);
        }
    }
}
