<?php

declare(strict_types=1);

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function asset(string $path): string
{
    return '/assets/' . ltrim($path, '/');
}

function project_image_thumbnail_path(string $path): string
{
    if (
        preg_match('~^uploads/([a-f0-9]{32})\.webp$~D', $path, $matches)
        && is_file(PROJECT_ROOT . '/assets/uploads/thumbs/' . $matches[1] . '.webp')
    ) {
        return 'uploads/thumbs/' . $matches[1] . '.webp';
    }

    foreach (['images/demo-gallery', 'images/site', 'images/services'] as $dir) {
        $pattern = '~^' . preg_quote($dir, '~') . '/([a-z0-9-]+)\.webp$~D';
        if (
            preg_match($pattern, $path, $matches)
            && is_file(PROJECT_ROOT . '/assets/' . $dir . '/thumbs/' . $matches[1] . '.webp')
        ) {
            return $dir . '/thumbs/' . $matches[1] . '.webp';
        }
    }

    return $path;
}

function project_image_categories(): array
{
    return [
        'building-construction' => 'Building Construction',
        'residential' => 'Residential',
        'commercial' => 'Commercial',
        'roads' => 'Roads',
        'civil-works' => 'Civil Works',
        'roofing' => 'Roofing',
        'concrete' => 'Concrete',
        'electrical' => 'Electrical',
        'plumbing' => 'Plumbing',
        'renovation' => 'Renovation',
        'equipment' => 'Equipment',
        'workers' => 'Workers',
        'safety' => 'Safety',
        'completed-projects' => 'Completed Projects',
    ];
}

function redirect(string $location): void
{
    header('Location: ' . $location, true, 303);
    exit;
}

function public_content_version(): string
{
    $tables = [
        'company_settings',
        'services',
        'projects',
        'project_images',
        'testimonials',
        'team_members',
        'blog_categories',
        'blog_posts',
    ];
    $queries = [];

    foreach ($tables as $table) {
        $queries[] = sprintf(
            "SELECT '%1\$s' AS table_name, COUNT(*) AS row_count, COALESCE(MAX(updated_at), '') AS last_modified FROM `%1\$s`",
            $table
        );
    }

    $statement = db()->query(implode(' UNION ALL ', $queries));
    $fingerprints = $statement->fetchAll();

    return hash('sha256', json_encode($fingerprints, JSON_THROW_ON_ERROR));
}

function company_settings(): array
{
    static $settings = null;

    if ($settings !== null) {
        return $settings;
    }

    $environmentPhone = getenv('COMPANY_PHONE') ?: '';
    $companyName = getenv('COMPANY_NAME') ?: 'ICON Construction Company';
    $settings = [
        'company_name' => $companyName,
        'company_tagline' => getenv('COMPANY_TAGLINE') ?: 'Sample Ugandan construction business',
        'company_description' => getenv('COMPANY_DESCRIPTION') ?: $companyName . ' is a sample Ugandan construction business focused on delivering reliable building, renovation, civil works and project solutions. The company emphasizes quality workmanship, safety, responsible project management and customer satisfaction.',
        'company_demo_notice' => '',
        'company_hero_heading' => "Building Uganda's Future, One Project at a Time.",
        'company_hero_subheading' => 'ICON Construction Company is a sample Ugandan construction business focused on reliable building, renovation, civil works and project solutions.',
        'company_service_area' => 'Kampala, Uganda',
        'company_phone' => $environmentPhone,
        'company_whatsapp' => getenv('COMPANY_WHATSAPP') ?: $environmentPhone,
        'company_email' => getenv('COMPANY_EMAIL') ?: '',
        'company_address' => getenv('COMPANY_ADDRESS') ?: 'Kampala, Uganda',
        'company_google_maps_location' => '',
        'company_business_hours' => '',
        'company_facebook_url' => '',
        'company_instagram_url' => '',
        'company_linkedin_url' => '',
        'company_logo' => 'images/icon-mark.svg',
        'company_favicon' => 'images/icon-mark.svg',
        'company_hero_image' => 'images/hero-construction.jpg',
        'company_hero_image_1' => 'images/hero/hero-1.webp',
        'company_hero_image_1_alt' => 'Building construction and site work with workers and steel reinforcement',
        'company_hero_image_2' => 'images/hero/hero-2.webp',
        'company_hero_image_2_alt' => 'Construction workers and engineers coordinating on site',
        'company_hero_image_3' => 'images/hero/hero-3.webp',
        'company_hero_image_3_alt' => 'Heavy construction equipment and civil works on site',
        'company_hero_image_4' => 'images/hero/hero-4.webp',
        'company_hero_image_4_alt' => 'Completed modern commercial building project',
        'company_safety_image' => 'images/site/safety-ppe.webp',
    ];

    $processSteps = [
        ['Consultation', 'Every project starts with a conversation about what you want to build, improve or repair. We discuss how the space will be used, your priorities, preferred timeline and budget range, then record the key requirements and questions to explore. This gives both sides a clear starting brief before site visits, designs or estimates are prepared.'],
        ['Site Assessment', 'We review the site and the conditions that may affect the work, including access, existing structures, ground levels, drainage, utilities and nearby activity. We discuss any visible constraints with you and identify information that may need specialist investigation. Findings help shape a practical scope; technical surveys or engineering checks are arranged where the project requires them.'],
        ['Planning & Design', 'Using the agreed brief and site information, the project team develops or reviews the drawings, specifications and sequence of work needed to define the project. We discuss material options, finish expectations, approvals and any decisions still required, so changes can be considered before construction. Design work, permits and statutory approvals are confirmed with the appropriate qualified professionals and authorities.'],
        ['Cost Estimation', 'Once the scope is clear enough to price, we prepare an itemised estimate showing the proposed work, materials, labour and other agreed cost items in Ugandan shillings. We explain assumptions, exclusions, allowances and any items that could change if site conditions or selections differ. You can review the estimate, ask questions and agree on revisions before deciding whether to proceed.'],
        ['Contract & Mobilization', 'Before work begins, the parties review and agree the scope, drawings, price, payment stages, schedule, responsibilities and process for handling changes. After the agreement is documented, the team plans site access, safety arrangements, material deliveries, staffing and the first work sequence. Mobilization proceeds when required approvals, access and agreed start conditions are in place.'],
        ['Construction', 'The agreed work is carried out in planned stages, with coordination between the site team, client and relevant suppliers or specialists. Progress, upcoming decisions and any issue affecting the scope or schedule are discussed as the work advances. Materials and workmanship are checked at suitable stages, and changes are reviewed and agreed before additional work is undertaken.'],
        ['Quality Inspection', 'As work reaches its agreed milestones and completion, the team checks finished items against the drawings, specifications and scope. We walk through the relevant areas with you, record outstanding or corrective items and agree how they will be addressed. Inspections required from engineers, consultants or authorities are coordinated separately where applicable to the project.'],
        ['Handover', 'At handover, we review the completed work with you, confirm the status of agreed outstanding items and share relevant keys, operating guidance, warranties or product information available for the project. We clarify any agreed follow-up arrangements and record completion of the handover. The aim is to leave you with a clear understanding of the finished space and its documentation.'],
    ];
    foreach ($processSteps as $index => [$title, $description]) {
        $number = $index + 1;
        $settings['company_process_' . $number . '_title'] = $title;
        $settings['company_process_' . $number . '_description'] = $description;
    }

    if (
        getenv('DB_HOST') === false
        || getenv('DB_NAME') === false
        || getenv('DB_USER') === false
        || getenv('DB_PASSWORD') === false
    ) {
        return $settings;
    }

    try {
        $statement = db()->prepare(
            'SELECT setting_key, setting_value
            FROM company_settings
            WHERE is_public = :is_public'
        );
        $statement->execute(['is_public' => 1]);

        foreach ($statement->fetchAll() as $setting) {
            $value = trim((string) $setting['setting_value']);

            if (
                array_key_exists($setting['setting_key'], $settings)
                && ($value !== '' || $setting['setting_key'] === 'company_demo_notice')
            ) {
                $settings[$setting['setting_key']] = $value;
            }
        }
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON company settings query failed: ' . $error->getMessage());
    }

    return $settings;
}

function company_setting(string $key): string
{
    $settings = company_settings();

    return $settings[$key] ?? '';
}

function company_demo_notice(): string
{
    $notice = trim((string) company_setting('company_demo_notice'));
    $defaultDemoNotice = 'SAMPLE / DEMO INFORMATION: Company details, service information and imagery are illustrative, not verified business facts. Replace them with approved company information in Admin → Company Settings before publishing.';

    return $notice === $defaultDemoNotice ? '' : $notice;
}

function company_process_steps(): array
{
    $steps = [];
    $fallbacks = [
        1 => 'images/site/process-consultation.webp',
        2 => 'images/site/process-site-assessment.webp',
        3 => 'images/site/process-planning.webp',
        4 => 'images/site/process-cost-estimation.webp',
        5 => 'images/site/process-construction.webp',
        6 => 'images/site/process-quality-inspection.webp',
        7 => 'images/site/process-handover.webp',
        8 => 'images/site/process-handover.webp',
    ];

    for ($number = 1; $number <= 8; $number++) {
        $title = company_setting('company_process_' . $number . '_title');
        $description = company_setting('company_process_' . $number . '_description');
        $image = company_setting('company_process_' . $number . '_image');
        if ($image === '' && isset($fallbacks[$number])) {
            $image = $fallbacks[$number];
        }
        if ($title !== '' && $description !== '') {
            $steps[] = ['title' => $title, 'description' => $description, 'image' => $image];
        }
    }

    return $steps;
}

function company_phone_display(): string
{
    $phone = company_setting('company_phone');
    $digits = preg_replace('/\D/', '', $phone);

    if (preg_match('/^256([237]\d{8})$/', $digits, $matches)) {
        return '+256 ' . substr($matches[1], 0, 3) . ' ' . substr($matches[1], 3, 3) . ' ' . substr($matches[1], 6);
    }

    if (preg_match('/^0([237]\d{8})$/', $digits, $matches)) {
        return '0' . substr($matches[1], 0, 3) . ' ' . substr($matches[1], 3, 3) . ' ' . substr($matches[1], 6);
    }

    return $phone;
}

function format_ugx(int|float|string|null $amount): string
{
    if ($amount === null || !is_numeric($amount)) {
        return 'Not specified';
    }

    return 'UGX ' . number_format((float) $amount, 0, '.', ',');
}

function company_asset_href(string $settingKey, ?string $fallback = null): string
{
    $path = company_setting($settingKey);

    if ($path === '' && $fallback !== null) {
        $path = $fallback;
    }

    if (
        str_starts_with($path, '/')
        || str_contains($path, '\\')
        || preg_match('/[\x00-\x1F]/', $path)
        || in_array('..', explode('/', $path), true)
        || !preg_match('~^(?:uploads|images)/[a-zA-Z0-9._/-]+$~D', $path)
    ) {
        return $fallback === null ? '' : asset($fallback);
    }

    return asset($path);
}

function company_phone_href(): string
{
    $phone = preg_replace('/[^0-9+]/', '', company_setting('company_phone'));

    return $phone === '' ? '' : 'tel:' . $phone;
}

function company_maps_embed_href(): string
{
    $location = trim(company_setting('company_google_maps_location'));

    if ($location === '') {
        $location = company_setting('company_address');
    }

    if ($location === '' || strtolower($location) === 'uganda' || filter_var($location, FILTER_VALIDATE_URL) !== false) {
        return '';
    }

    return 'https://www.google.com/maps?q=' . rawurlencode($location) . '&output=embed';
}

function company_maps_href(): string
{
    $location = trim(company_setting('company_google_maps_location'));

    if ($location === '') {
        $location = company_setting('company_address');
    }

    if ($location === '' || strtolower($location) === 'uganda') {
        return '';
    }

    if (filter_var($location, FILTER_VALIDATE_URL) !== false) {
        $host = strtolower((string) parse_url($location, PHP_URL_HOST));
        $allowedHosts = ['google.com', 'www.google.com', 'maps.google.com', 'maps.app.goo.gl', 'goo.gl'];

        if (strtolower((string) parse_url($location, PHP_URL_SCHEME)) === 'https' && in_array($host, $allowedHosts, true)) {
            return $location;
        }
    }

    return 'https://www.google.com/maps/search/?api=1&query=' . rawurlencode($location);
}

function company_social_href(string $settingKey): string
{
    $url = trim(company_setting($settingKey));

    if (filter_var($url, FILTER_VALIDATE_URL) === false) {
        return '';
    }

    $host = strtolower((string) parse_url($url, PHP_URL_HOST));
    $allowedHosts = match ($settingKey) {
        'company_facebook_url' => ['facebook.com', 'www.facebook.com', 'm.facebook.com'],
        'company_instagram_url' => ['instagram.com', 'www.instagram.com'],
        'company_linkedin_url' => ['linkedin.com', 'www.linkedin.com'],
        default => [],
    };

    return strtolower((string) parse_url($url, PHP_URL_SCHEME)) === 'https'
        && in_array($host, $allowedHosts, true)
        ? $url
        : '';
}

function company_whatsapp_href(): string
{
    $number = company_setting('company_whatsapp') ?: company_setting('company_phone');
    $number = preg_replace('/\D/', '', $number);

    if ($number === '') {
        return '';
    }

    if (str_starts_with($number, '0')) {
        $number = '256' . substr($number, 1);
    } elseif (!str_starts_with($number, '256')) {
        $number = '256' . $number;
    }

    if (strlen($number) < 11 || strlen($number) > 15) {
        return '';
    }

    return 'https://wa.me/' . $number;
}
