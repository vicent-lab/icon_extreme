-- Run once on databases created from the original ICON schema.
-- Import database/schema.sql instead for a brand-new database.

ALTER TABLE services
    CHANGE COLUMN title name VARCHAR(160) NOT NULL,
    CHANGE COLUMN description short_description TEXT NOT NULL,
    ADD COLUMN full_description TEXT NULL AFTER short_description,
    ADD COLUMN icon VARCHAR(80) NOT NULL DEFAULT 'building' AFTER full_description,
    ADD COLUMN image VARCHAR(255) NULL AFTER icon,
    ADD COLUMN is_featured TINYINT(1) NOT NULL DEFAULT 0 AFTER image,
    ADD COLUMN status ENUM('active', 'inactive') NOT NULL DEFAULT 'inactive' AFTER display_order;

UPDATE services
SET full_description = short_description,
    status = IF(is_published = 1, 'active', 'inactive');

ALTER TABLE services
    MODIFY COLUMN full_description TEXT NOT NULL,
    DROP COLUMN is_published,
    DROP INDEX services_published_order_index,
    ADD KEY services_status_order_index (status, display_order),
    ADD KEY services_featured_index (status, is_featured, display_order);