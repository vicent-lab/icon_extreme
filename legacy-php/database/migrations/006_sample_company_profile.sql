-- Update only the previous built-in sample values; preserve administrator edits.
UPDATE company_settings
SET setting_value = 'Sample Ugandan construction business'
WHERE setting_key = 'company_tagline'
  AND setting_value = 'Construction solutions, grounded in Uganda';

UPDATE company_settings
SET setting_value = 'ICON Construction Company is a sample Ugandan construction business focused on delivering reliable building, renovation, civil works and project solutions. The company emphasizes quality workmanship, safety, responsible project management and customer satisfaction.'
WHERE setting_key = 'company_description'
  AND setting_value = 'Professional construction, civil works, renovations and project solutions delivered with quality, safety and integrity.';

UPDATE company_settings
SET setting_value = 'Building Uganda''s Future, One Project at a Time.'
WHERE setting_key = 'company_hero_heading'
  AND setting_value = 'Building Uganda’s Future, One Project at a Time.';

UPDATE company_settings
SET setting_value = 'ICON Construction Company is a sample Ugandan construction business focused on reliable building, renovation, civil works and project solutions.'
WHERE setting_key = 'company_hero_subheading'
  AND setting_value = 'Professional construction, civil works, renovations and project solutions delivered with quality, safety and integrity.';

UPDATE company_settings
SET setting_value = 'Kampala, Uganda'
WHERE setting_key IN ('company_service_area', 'company_address')
  AND setting_value IN ('Uganda', 'Kampala and communities across Uganda');

INSERT INTO company_settings (setting_key, setting_value, is_public)
SELECT
    'company_demo_notice',
    '',
    1
WHERE NOT EXISTS (
    SELECT 1
    FROM company_settings
    WHERE setting_key = 'company_demo_notice'
);
