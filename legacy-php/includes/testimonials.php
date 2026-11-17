<?php

declare(strict_types=1);

/**
 * Upload and optimize a client photo.
 * Crops to a 1:1 aspect ratio square and converts to WebP.
 *
 * @param array $file The uploaded $_FILES entry
 * @return string Relative asset path e.g. "uploads/testimonials/{hash}.webp"
 */
function testimonial_photo_upload(array $file): string
{
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK || !is_string($file['tmp_name'] ?? null)) {
        throw new InvalidArgumentException('Choose a valid client photo file.');
    }

    if ((int) ($file['size'] ?? 0) > 5 * 1024 * 1024) {
        throw new InvalidArgumentException('Client photo must be 5 MB or smaller.');
    }

    $imageInfo = @getimagesize($file['tmp_name']);
    $mime = is_array($imageInfo) ? ($imageInfo['mime'] ?? '') : '';
    $allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
    $width = is_array($imageInfo) ? (int) ($imageInfo[0] ?? 0) : 0;
    $height = is_array($imageInfo) ? (int) ($imageInfo[1] ?? 0) : 0;

    if (!in_array($mime, $allowedMimes, true) || $width < 1 || $height < 1) {
        throw new InvalidArgumentException('Upload a valid JPEG, PNG or WebP image.');
    }

    if ($width > 8000 || $height > 8000) {
        throw new InvalidArgumentException('Image dimensions must be no larger than 8000 × 8000 pixels.');
    }

    if (!function_exists('imagewebp') || !function_exists('imagecreatefromstring')) {
        throw new RuntimeException('GD with WebP support is required to optimize images.');
    }

    $sourceBytes = file_get_contents($file['tmp_name']);
    $source = is_string($sourceBytes) ? @imagecreatefromstring($sourceBytes) : false;
    if ($source === false) {
        throw new InvalidArgumentException('The uploaded photo could not be decoded.');
    }

    $filename = bin2hex(random_bytes(16));
    $uploadDirectory = PROJECT_ROOT . '/assets/uploads/testimonials';
    $thumbnailDirectory = $uploadDirectory . '/thumbs';

    foreach ([$uploadDirectory, $thumbnailDirectory] as $dir) {
        if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
            imagedestroy($source);
            throw new RuntimeException('The testimonial upload directory could not be created.');
        }
    }

    $imagePath = 'uploads/testimonials/' . $filename . '.webp';
    $imageDestination = PROJECT_ROOT . '/assets/' . $imagePath;
    $thumbnailDestination = $thumbnailDirectory . '/' . $filename . '.webp';

    try {
        // Crop center square
        $srcW = imagesx($source);
        $srcH = imagesy($source);
        $squareSize = min($srcW, $srcH);
        $srcX = (int) floor(($srcW - $squareSize) / 2);
        $srcY = (int) floor(($srcH - $squareSize) / 2);

        // Standard avatar: 400x400
        $targetSize = min(400, $squareSize);
        $resized = imagecreatetruecolor($targetSize, $targetSize);
        imagealphablending($resized, false);
        imagesavealpha($resized, true);
        imagecopyresampled(
            $resized,
            $source,
            0,
            0,
            $srcX,
            $srcY,
            $targetSize,
            $targetSize,
            $squareSize,
            $squareSize
        );

        if (!imagewebp($resized, $imageDestination, 84)) {
            imagedestroy($resized);
            throw new RuntimeException('The client photo could not be saved.');
        }

        // Small thumbnail: 120x120
        $thumbSize = 120;
        $thumb = imagecreatetruecolor($thumbSize, $thumbSize);
        imagealphablending($thumb, false);
        imagesavealpha($thumb, true);
        imagecopyresampled(
            $thumb,
            $resized,
            0,
            0,
            0,
            0,
            $thumbSize,
            $thumbSize,
            $targetSize,
            $targetSize
        );

        $thumbSaved = imagewebp($thumb, $thumbnailDestination, 80);
        imagedestroy($thumb);
        imagedestroy($resized);

        if (!$thumbSaved) {
            throw new RuntimeException('The photo thumbnail could not be saved.');
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

/**
 * Upload and optimize a client company logo.
 * Preserves alpha transparency and bounds to standard dimensions.
 *
 * @param array $file The uploaded $_FILES entry
 * @return string Relative asset path e.g. "uploads/testimonials/logos/{hash}.webp"
 */
function testimonial_logo_upload(array $file): string
{
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK || !is_string($file['tmp_name'] ?? null)) {
        throw new InvalidArgumentException('Choose a valid logo file.');
    }

    if ((int) ($file['size'] ?? 0) > 5 * 1024 * 1024) {
        throw new InvalidArgumentException('Logo file must be 5 MB or smaller.');
    }

    $clientFilename = (string) ($file['name'] ?? '');
    $clientExt = strtolower(pathinfo($clientFilename, PATHINFO_EXTENSION));

    $logoDirectory = PROJECT_ROOT . '/assets/uploads/testimonials/logos';
    if (!is_dir($logoDirectory) && !mkdir($logoDirectory, 0755, true) && !is_dir($logoDirectory)) {
        throw new RuntimeException('The logo upload directory could not be created.');
    }

    $filename = bin2hex(random_bytes(16));

    // Handle SVG files
    if ($clientExt === 'svg') {
        $svgContent = file_get_contents($file['tmp_name']);
        if ($svgContent === false || !str_contains($svgContent, '<svg') || str_contains(strtolower($svgContent), '<script')) {
            throw new InvalidArgumentException('Upload a valid and safe SVG file.');
        }

        $imagePath = 'uploads/testimonials/logos/' . $filename . '.svg';
        $destination = PROJECT_ROOT . '/assets/' . $imagePath;
        if (file_put_contents($destination, $svgContent) === false) {
            throw new RuntimeException('The SVG logo could not be saved.');
        }

        return $imagePath;
    }

    // Raster logo handling (PNG, WebP, JPEG)
    $imageInfo = @getimagesize($file['tmp_name']);
    $mime = is_array($imageInfo) ? ($imageInfo['mime'] ?? '') : '';
    $allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];

    if (!in_array($mime, $allowedMimes, true)) {
        throw new InvalidArgumentException('Upload a valid PNG, SVG, WebP or JPEG logo.');
    }

    $sourceBytes = file_get_contents($file['tmp_name']);
    $source = is_string($sourceBytes) ? @imagecreatefromstring($sourceBytes) : false;
    if ($source === false) {
        throw new InvalidArgumentException('The uploaded logo could not be decoded.');
    }

    $srcW = imagesx($source);
    $srcH = imagesy($source);
    $maxW = 480;
    $maxH = 180;

    $scale = min(1.0, $maxW / $srcW, $maxH / $srcH);
    $targetW = max(1, (int) round($srcW * $scale));
    $targetH = max(1, (int) round($srcH * $scale));

    $resized = imagecreatetruecolor($targetW, $targetH);
    imagealphablending($resized, false);
    imagesavealpha($resized, true);

    imagecopyresampled(
        $resized,
        $source,
        0,
        0,
        0,
        0,
        $targetW,
        $targetH,
        $srcW,
        $srcH
    );

    $imagePath = 'uploads/testimonials/logos/' . $filename . '.webp';
    $destination = PROJECT_ROOT . '/assets/' . $imagePath;

    $saved = imagewebp($resized, $destination, 90);
    imagedestroy($resized);
    imagedestroy($source);

    if (!$saved) {
        if (is_file($destination)) {
            unlink($destination);
        }
        throw new RuntimeException('The company logo could not be saved.');
    }

    return $imagePath;
}

/**
 * Safely delete an uploaded testimonial asset.
 */
function testimonial_delete_file(string $path): void
{
    $cleanPath = ltrim(str_replace(['../', '..\\'], '', $path), '/');

    if (!str_starts_with($cleanPath, 'uploads/testimonials/')) {
        return;
    }

    $fullPath = PROJECT_ROOT . '/assets/' . $cleanPath;
    if (is_file($fullPath)) {
        @unlink($fullPath);
    }

    // Also remove thumbnail if applicable
    if (preg_match('~^uploads/testimonials/([a-f0-9]{32})\.webp$~D', $cleanPath, $matches)) {
        $thumbPath = PROJECT_ROOT . '/assets/uploads/testimonials/thumbs/' . $matches[1] . '.webp';
        if (is_file($thumbPath)) {
            @unlink($thumbPath);
        }
    }
}

/**
 * Retrieve verified, published public testimonials.
 * Excludes all demonstration content.
 * Links to verified projects in database when available.
 *
 * @param int $limit
 * @return array
 */
function get_public_testimonials(int $limit = 12): array
{
    if (getenv('DB_HOST') === false || getenv('DB_NAME') === false) {
        return [];
    }

    try {
        $connection = db();

        $tableCheck = $connection->prepare(
            'SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = :table_name'
        );
        $tableCheck->execute(['table_name' => 'testimonials']);
        if ((int) $tableCheck->fetchColumn() === 0) {
            return [];
        }

        $projectsTableCheck = $connection->prepare(
            'SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = :table_name'
        );
        $projectsTableCheck->execute(['table_name' => 'projects']);
        $hasProjectsTable = (int) $projectsTableCheck->fetchColumn() > 0;

        // Query with left join to projects if table exists
        if ($hasProjectsTable) {
            $sql = 'SELECT
                t.id,
                t.client_name,
                t.client_role,
                t.company,
                t.project_id,
                t.project_name,
                t.location,
                t.client_photo,
                t.company_logo,
                t.quote,
                t.rating,
                t.is_published,
                t.is_featured,
                t.demonstration_content,
                t.display_order,
                t.created_at,
                p.id AS linked_project_id,
                p.slug AS linked_project_slug,
                p.title AS linked_project_title
            FROM testimonials t
            LEFT JOIN projects p ON (
                (t.project_id IS NOT NULL AND t.project_id = p.id)
                OR (t.project_id IS NULL AND t.project_name IS NOT NULL AND TRIM(t.project_name) <> \'\' AND LOWER(TRIM(p.title)) = LOWER(TRIM(t.project_name)))
            ) AND p.is_published = 1
            WHERE t.is_published = 1 AND t.demonstration_content = 0
            ORDER BY t.is_featured DESC, t.display_order ASC, t.created_at DESC
            LIMIT ' . (int) $limit;
        } else {
            $sql = 'SELECT
                t.id,
                t.client_name,
                t.client_role,
                t.company,
                t.project_id,
                t.project_name,
                t.location,
                t.client_photo,
                t.company_logo,
                t.quote,
                t.rating,
                t.is_published,
                t.is_featured,
                t.demonstration_content,
                t.display_order,
                t.created_at,
                NULL AS linked_project_id,
                NULL AS linked_project_slug,
                NULL AS linked_project_title
            FROM testimonials t
            WHERE t.is_published = 1 AND t.demonstration_content = 0
            ORDER BY t.is_featured DESC, t.display_order ASC, t.created_at DESC
            LIMIT ' . (int) $limit;
        }

        $stmt = $connection->prepare($sql);
        $stmt->execute();
        return $stmt->fetchAll() ?: [];
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON get_public_testimonials query failed: ' . $error->getMessage());
        return [];
    }
}

/**
 * Retrieve all active published projects for testimonial dropdown.
 *
 * @return array
 */
function get_all_projects_for_testimonial_select(): array
{
    try {
        $connection = db();
        $stmt = $connection->prepare(
            'SELECT id, title, slug, project_type, location
            FROM projects
            ORDER BY title ASC'
        );
        $stmt->execute();
        return $stmt->fetchAll() ?: [];
    } catch (Throwable) {
        return [];
    }
}

/**
 * Delete all demonstration testimonials and clean up their uploaded files.
 *
 * @return int Number of deleted demonstration records
 */
function delete_all_demonstration_testimonials(): int
{
    try {
        $connection = db();
        $select = $connection->prepare(
            'SELECT client_photo, company_logo FROM testimonials WHERE demonstration_content = 1'
        );
        $select->execute();
        $records = $select->fetchAll() ?: [];

        foreach ($records as $row) {
            if (!empty($row['client_photo'])) {
                testimonial_delete_file((string) $row['client_photo']);
            }
            if (!empty($row['company_logo'])) {
                testimonial_delete_file((string) $row['company_logo']);
            }
        }

        $delete = $connection->prepare('DELETE FROM testimonials WHERE demonstration_content = 1');
        $delete->execute();
        return $delete->rowCount();
    } catch (Throwable $error) {
        error_log('Failed to delete demonstration testimonials: ' . $error->getMessage());
        throw $error;
    }
}
