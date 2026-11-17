ALTER TABLE project_images
    ADD COLUMN category VARCHAR(50) NOT NULL DEFAULT 'building-construction' AFTER caption,
    ADD KEY project_images_category_index (project_id, category);
