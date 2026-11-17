# ICON Construction Company

A lightweight company website built with PHP 8+, MySQL/MariaDB, HTML, CSS and vanilla JavaScript. The public document root is `public/`; the administrator dashboard is available at `/admin/`.

## Requirements

- PHP 8 or later with PDO MySQL (`pdo_mysql`)
- MySQL 8+ or MariaDB 10.5+
- Apache with `mod_rewrite`/`mod_authz_core` for the supplied upload-directory rules, or PHP's built-in development server

## Project layout

```text
admin/                 Protected administration pages
assets/
  css/                 Base site styles
  images/              Brand mark and construction illustration
  js/                  Vanilla JavaScript
  uploads/             Admin-managed project images; script execution is denied
config/                Environment loading and PDO connection
database/              Initial MySQL schema
includes/              Shared layout, session, flash and utility components
public/                Web document root and homepage
  admin/               URL wrappers for the protected admin pages
```

The public asset URL `/assets/` is linked to the top-level `assets/` directory so source assets stay organized outside the document root.

## Local setup

1. Create a MySQL/MariaDB database and a dedicated database user. Grant that user access to the application database. In phpMyAdmin, create a database named `icon_construction` using `utf8mb4_unicode_ci`.
2. Copy `.env.example` to `.env` in the project root and set `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` and `DB_PASSWORD` for your local database. Company name, tagline, description and contact values in `.env` provide fallbacks for empty database settings. `.env` is ignored by Git and is outside the public document root.
3. For a new database, select `icon_construction` in phpMyAdmin and import `database/schema.sql`. If upgrading an earlier ICON database, run `database/migrations/001_enhance_services.sql`, `database/migrations/002_project_portfolio.sql`, `database/migrations/003_contact_quote.sql`, `database/migrations/004_admin_dashboard.sql`, `database/migrations/005_company_brand_settings.sql`, `database/migrations/006_sample_company_profile.sql`, `database/migrations/007_project_image_categories.sql`, `database/migrations/008_client_testimonials.sql` and `database/migrations/009_expand_construction_journey.sql` in that order to retain existing records and add the current site tables.
4. Import `database/seed.sql` to add the 12 sample services and initial company settings, including the expanded construction journey, and optionally `database/projects-demo-seed.sql` to add clearly marked demonstration projects in Kampala, Wakiso, Mukono, Entebbe and Jinja. These are sample content only—not claims about real company work. The seed uses `INSERT IGNORE`, so re-importing it won't overwrite existing records.
5. Treat all included company, service and project content as sample/demo information, not verified facts about ICON Construction Company. The public website displays a demo notice until an administrator clears `company_demo_notice` in Company Settings. Before publishing, replace sample company copy, location, services, contact information, images and any demonstration projects with approved, verified information. Set `company_address` to the verified business address. If WhatsApp should use the same number as calls, leave `company_whatsapp` blank. Environment values in `.env` provide fallbacks when database settings are empty.
6. Point your Apache virtual host's `DocumentRoot` to the project's `public/` directory. Do not expose the project root as the document root.
7. For a quick local preview, run from the project root:

   ```sh
   php -S 127.0.0.1:8000 -t public
   ```

   Then open `http://127.0.0.1:8000`.

## Administrator access

After importing the schema or applying all migrations and configuring `.env`, create the first administrator from an interactive terminal:

```sh
php database/create-admin.php
```

The command prompts for name, email, role and a password (minimum 12 characters). The password is hidden while entered and saved only as a `password_hash()` hash. Do not add a default password or manually expose this script through the website. Sign in at `/admin/login.php`.

Administrators can manage website content and company settings. Editor accounts can manage projects/images, services, testimonials, team members and blog content. Support accounts can manage contact messages and quote requests. All admin pages require an active account; state-changing forms use CSRF tokens, delete actions require browser confirmation, and uploaded project images are restricted to JPEG, PNG or WebP (5 MB maximum).

The Company settings screen controls the sample/demo notice, company name, tagline and description, contact details, physical address, Google Maps location, business hours, social links, logo, favicon and homepage hero image. These settings are shared by the public header/footer, metadata, contact surfaces and homepage; if a field is empty, the site uses its built-in default or existing `.env` fallback. Leave the sample/demo notice in place until the public content has been replaced and verified; clearing it hides the notice. Logo and hero uploads accept PNG/JPEG/WebP; favicon uploads accept PNG/ICO. Each image is size-limited, content-checked and stored under `assets/uploads/`.

Dashboard content changes are checked by public pages every five seconds. Open pages reload automatically when published content changes; if a visitor has edited a form, the page waits and offers a refresh button so their input is not lost.

The homepage and `/services.php` load active service records from MySQL. Each service links to `/service.php?slug=...`. The `/projects.php` portfolio can be filtered by project type, status and location; each project links to `/project-details.php?id=...`, including a responsive image lightbox. Only published projects are displayed. Demo portfolio records are visibly marked as sample content and are not represented as ICON's real projects. The `/about.php` page uses editable company settings and process steps and displays active team members. Published blog articles are listed at `/blog.php` and displayed at `/blog-post.php?slug=...`; drafts and future-dated posts are not public. The `/contact.php` and `/quote.php` forms use server-side validation, CSRF tokens, a honeypot, a minimum completion time and per-session rate limiting before saving with PDO prepared statements. Public company branding, contact details, maps, hours and social links are provided by the shared `company_settings()` helper with sensible defaults. Without a database connection, dynamic submissions are not reported as successful and the forms display a friendly error instead. Database access is provided by `db()` in `config/database.php`; query failures are written to the PHP error log without exposing database errors to visitors.

## Verify the database connection

After creating `.env` and importing the schema, run this from the project root:

```sh
php -r "require 'config/bootstrap.php'; db()->query('SELECT 1'); echo 'MySQL connection successful', PHP_EOL;"
```

This uses the same environment loading and PDO connection as the application. Do not commit `.env` or put database credentials in public files.
