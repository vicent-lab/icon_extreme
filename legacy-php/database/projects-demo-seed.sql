-- FICTIONAL DEMONSTRATION CONTENT ONLY.
-- These six projects, clients, locations, dates and galleries are samples and
-- are not claims about work completed by ICON Construction Company.
-- Run database/generate-demo-gallery.php before importing this file.
-- INSERT IGNORE makes this seed safe to re-run without overwriting edits.

INSERT IGNORE INTO projects (
    title,
    slug,
    description,
    location,
    project_type,
    client,
    status,
    start_date,
    completion_date,
    featured_image,
    is_featured,
    is_published,
    is_demo,
    display_order
) VALUES
(
    'Demo · Modern Residential Development',
    'demo-modern-residential-development',
    'FICTIONAL DEMONSTRATION PROJECT — A sample residential development concept in Kampala, used to showcase the project gallery and portfolio layout. Project details, people and imagery are illustrative only and do not describe actual ICON work.',
    'Kampala',
    'Residential Construction',
    'Sample Client · Cedar House Studio',
    'completed',
    '2024-02-01',
    '2024-11-15',
    'images/demo-gallery/18-completed-building.webp',
    1,
    1,
    1,
    1
),
(
    'Demo · Commercial Office Building',
    'demo-commercial-office-building',
    'FICTIONAL DEMONSTRATION PROJECT — A sample office building portfolio record in Entebbe. Scope, client, dates and imagery are fictional placeholders created for visual and workflow demonstrations.',
    'Entebbe',
    'Commercial Construction',
    'Sample Client · Northline Workspaces',
    'ongoing',
    '2025-03-10',
    NULL,
    'images/demo-gallery/14-exterior-finishing.webp',
    1,
    1,
    1,
    2
),
(
    'Demo · Apartment Development',
    'demo-apartment-development',
    'FICTIONAL DEMONSTRATION PROJECT — A sample apartment development concept in Wakiso. All project information and accompanying gallery imagery are illustrative and are not represented as a real ICON project.',
    'Wakiso',
    'Residential Construction',
    'Sample Client · East Ridge Living',
    'upcoming',
    '2026-08-03',
    NULL,
    'images/demo-gallery/11-plastering.webp',
    0,
    1,
    1,
    3
),
(
    'Demo · Road & Drainage Works',
    'demo-road-drainage-works',
    'FICTIONAL DEMONSTRATION PROJECT — A sample road access and drainage coordination record in Jinja. The location, scope, client and imagery are fictional examples for development and must not be interpreted as verified project experience.',
    'Jinja',
    'Civil & Road Works',
    'Sample Client · Riverbend Developments',
    'ongoing',
    '2025-07-14',
    NULL,
    'images/demo-gallery/01-site-preparation.webp',
    0,
    1,
    1,
    4
),
(
    'Demo · House Renovation Project',
    'demo-house-renovation-project',
    'FICTIONAL DEMONSTRATION PROJECT — A sample home renovation record in Mukono. All property details, dates, client information and imagery are fictional and exist only to demonstrate the portfolio.',
    'Mukono',
    'Renovation & Remodeling',
    'Sample Client · Acacia Home Collective',
    'completed',
    '2023-06-05',
    '2024-01-30',
    'images/demo-gallery/15-interior-finishing.webp',
    0,
    1,
    1,
    5
),
(
    'Demo · Small Commercial Complex',
    'demo-small-commercial-complex',
    'FICTIONAL DEMONSTRATION PROJECT — A sample neighbourhood commercial complex record in Kampala. This illustrative portfolio content is not a real client or ICON construction project.',
    'Kampala',
    'Commercial Construction',
    'Sample Client · Market Square Partners',
    'completed',
    '2024-04-15',
    '2025-02-20',
    'images/demo-gallery/17-final-inspection.webp',
    0,
    1,
    1,
    6
);

INSERT IGNORE INTO project_images (
    project_id,
    image_path,
    alt_text,
    caption,
    category,
    display_order
)
SELECT
    p.id,
    gallery.image_path,
    CONCAT(gallery.alt_text, ' · ', p.title, ' · fictional sample content'),
    gallery.caption,
    gallery.category,
    gallery.display_order
FROM projects p
CROSS JOIN (
    SELECT 1 AS display_order, 'images/demo-gallery/01-site-preparation.webp' AS image_path, 'Site preparation on a construction project' AS alt_text, '1. Site preparation · demonstration only.' AS caption, 'building-construction' AS category
    UNION ALL SELECT 2, 'images/demo-gallery/02-foundation-excavation.webp', 'Foundation excavation in progress', '2. Foundation excavation · demonstration only.', 'civil-works'
    UNION ALL SELECT 3, 'images/demo-gallery/03-foundation-works.webp', 'Foundation works at a building site', '3. Foundation works · demonstration only.', 'concrete'
    UNION ALL SELECT 4, 'images/demo-gallery/04-reinforcement.webp', 'Reinforcement steel prepared for concrete works', '4. Reinforcement · demonstration only.', 'concrete'
    UNION ALL SELECT 5, 'images/demo-gallery/05-concrete-foundation.webp', 'Concrete foundation being formed', '5. Concrete foundation · demonstration only.', 'concrete'
    UNION ALL SELECT 6, 'images/demo-gallery/06-wall-construction.webp', 'Wall construction stage of a building', '6. Wall construction · demonstration only.', 'building-construction'
    UNION ALL SELECT 7, 'images/demo-gallery/07-structural-works.webp', 'Structural works during construction', '7. Structural works · demonstration only.', 'building-construction'
    UNION ALL SELECT 8, 'images/demo-gallery/08-roofing-stage.webp', 'Roofing stage of a building project', '8. Roofing · demonstration only.', 'roofing'
    UNION ALL SELECT 9, 'images/demo-gallery/09-plumbing-installation.webp', 'Plumbing installation coordination', '9. Plumbing installation · demonstration only.', 'plumbing'
    UNION ALL SELECT 10, 'images/demo-gallery/10-electrical-installation.webp', 'Electrical installation coordination', '10. Electrical installation · demonstration only.', 'electrical'
    UNION ALL SELECT 11, 'images/demo-gallery/11-plastering.webp', 'Plastering and surface preparation', '11. Plastering · demonstration only.', 'building-construction'
    UNION ALL SELECT 12, 'images/demo-gallery/12-flooring.webp', 'Flooring works in progress', '12. Flooring · demonstration only.', 'residential'
    UNION ALL SELECT 13, 'images/demo-gallery/13-painting-finishing.webp', 'Painting and interior finishing', '13. Painting · demonstration only.', 'renovation'
    UNION ALL SELECT 14, 'images/demo-gallery/14-exterior-finishing.webp', 'Exterior finishing details', '14. Exterior finishing · demonstration only.', 'commercial'
    UNION ALL SELECT 15, 'images/demo-gallery/15-interior-finishing.webp', 'Interior finishing and fit-out', '15. Interior finishing · demonstration only.', 'residential'
    UNION ALL SELECT 16, 'images/demo-gallery/16-landscaping.webp', 'Landscaping around a completed area', '16. Landscaping · demonstration only.', 'completed-projects'
    UNION ALL SELECT 17, 'images/demo-gallery/17-final-inspection.webp', 'Final inspection before handover', '17. Final inspection · demonstration only.', 'safety'
    UNION ALL SELECT 18, 'images/demo-gallery/18-completed-building.webp', 'Completed building after project delivery', '18. Completed building · demonstration only.', 'completed-projects'
) AS gallery
WHERE p.slug IN (
    'demo-modern-residential-development',
    'demo-commercial-office-building',
    'demo-apartment-development',
    'demo-road-drainage-works',
    'demo-house-renovation-project',
    'demo-small-commercial-complex'
);
