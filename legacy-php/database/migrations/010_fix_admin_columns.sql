-- Adds the columns the admin forms already write to (saving a project/post used to fail).
ALTER TABLE projects
    ADD COLUMN short_description VARCHAR(500) NULL AFTER description,
    ADD COLUMN project_manager VARCHAR(160) NULL,
    ADD COLUMN budget DECIMAL(15,2) UNSIGNED NULL,
    ADD COLUMN challenge TEXT NULL,
    ADD COLUMN solution TEXT NULL,
    ADD COLUMN results TEXT NULL,
    ADD COLUMN materials_used TEXT NULL;

ALTER TABLE blog_posts
    ADD COLUMN author VARCHAR(160) NULL,
    ADD COLUMN reading_time SMALLINT UNSIGNED NULL,
    ADD COLUMN seo_title VARCHAR(255) NULL,
    ADD COLUMN seo_description VARCHAR(500) NULL;
