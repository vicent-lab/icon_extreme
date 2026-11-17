-- Run once after 001_enhance_services.sql on databases created from the
-- original ICON schema. Import database/schema.sql on a brand-new database.

UPDATE projects
SET location = 'Uganda'
WHERE location IS NULL OR location = '';

ALTER TABLE projects
    CHANGE COLUMN summary description TEXT NOT NULL,
    CHANGE COLUMN image_path featured_image VARCHAR(255) NULL,
    MODIFY COLUMN location VARCHAR(180) NOT NULL DEFAULT 'Uganda',
    ADD COLUMN project_type VARCHAR(120) NOT NULL DEFAULT 'General Construction' AFTER location,
    ADD COLUMN client VARCHAR(180) NULL AFTER project_type,
    ADD COLUMN status ENUM('completed', 'ongoing', 'upcoming') NOT NULL DEFAULT 'upcoming' AFTER client,
    ADD COLUMN start_date DATE NULL AFTER status,
    ADD COLUMN completion_date DATE NULL AFTER start_date,
    ADD COLUMN is_featured TINYINT(1) NOT NULL DEFAULT 0 AFTER featured_image,
    ADD COLUMN is_demo TINYINT(1) NOT NULL DEFAULT 0 AFTER is_published,
    DROP INDEX projects_published_order_index,
    ADD KEY projects_published_order_index (is_published, display_order, created_at),
    ADD KEY projects_type_status_index (is_published, project_type, status),
    ADD KEY projects_location_index (is_published, location),
    ADD KEY projects_featured_index (is_published, is_featured, display_order);

CREATE TABLE project_images (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    project_id BIGINT UNSIGNED NOT NULL,
    image_path VARCHAR(255) NOT NULL,
    alt_text VARCHAR(255) NOT NULL,
    caption VARCHAR(255) NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'building-construction',
    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY project_images_path_unique (project_id, image_path),
    KEY project_images_order_index (project_id, display_order),
    KEY project_images_category_index (project_id, category),
    CONSTRAINT project_images_project_fk
        FOREIGN KEY (project_id) REFERENCES projects (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
