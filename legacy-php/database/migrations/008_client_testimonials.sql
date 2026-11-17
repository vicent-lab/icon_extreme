-- Migration 008: Enhance client testimonials / reviews system
-- Run on existing ICON databases to add project connections, permission tracking, and demonstration isolation.

CREATE TABLE IF NOT EXISTS testimonials (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    client_name VARCHAR(160) NOT NULL,
    client_role VARCHAR(160) NULL,
    company VARCHAR(180) NULL,
    project_id BIGINT UNSIGNED NULL,
    project_name VARCHAR(180) NULL,
    location VARCHAR(180) NULL,
    client_photo VARCHAR(255) NULL,
    company_logo VARCHAR(255) NULL,
    quote TEXT NOT NULL,
    rating TINYINT UNSIGNED NULL,
    is_published TINYINT(1) NOT NULL DEFAULT 0,
    is_featured TINYINT(1) NOT NULL DEFAULT 0,
    demonstration_content TINYINT(1) NOT NULL DEFAULT 0,
    client_permission TINYINT(1) NOT NULL DEFAULT 1,
    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY testimonials_published_order_index (is_published, demonstration_content, display_order),
    KEY testimonials_featured_index (is_published, is_featured, display_order),
    KEY testimonials_project_id_index (project_id),
    CONSTRAINT testimonials_project_fk
        FOREIGN KEY (project_id) REFERENCES projects (id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Apply incremental column updates for databases created with earlier schema versions:
ALTER TABLE testimonials
    ADD COLUMN IF NOT EXISTS client_role VARCHAR(160) NULL AFTER client_name,
    ADD COLUMN IF NOT EXISTS project_id BIGINT UNSIGNED NULL AFTER company,
    ADD COLUMN IF NOT EXISTS project_name VARCHAR(180) NULL AFTER project_id,
    ADD COLUMN IF NOT EXISTS location VARCHAR(180) NULL AFTER project_name,
    ADD COLUMN IF NOT EXISTS client_photo VARCHAR(255) NULL AFTER location,
    ADD COLUMN IF NOT EXISTS company_logo VARCHAR(255) NULL AFTER client_photo,
    ADD COLUMN IF NOT EXISTS is_featured TINYINT(1) NOT NULL DEFAULT 0 AFTER is_published,
    ADD COLUMN IF NOT EXISTS demonstration_content TINYINT(1) NOT NULL DEFAULT 0 AFTER is_featured,
    ADD COLUMN IF NOT EXISTS client_permission TINYINT(1) NOT NULL DEFAULT 1 AFTER demonstration_content,
    MODIFY COLUMN rating TINYINT UNSIGNED NULL DEFAULT NULL;
