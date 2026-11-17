<?php

declare(strict_types=1);

$navigationPhone = company_setting('company_phone');
$navigationPhoneHref = company_phone_href();
$navigationEmail = company_setting('company_email');
$navigationWhatsapp = company_whatsapp_href();
$companyName = company_setting('company_name');
$companyLogo = company_asset_href('company_logo');
$companyTagline = company_setting('company_tagline');
?>
<header class="site-header" id="site-header">
    <div class="container site-header__inner">
        <a class="brand" href="/" aria-label="<?= e($companyName) ?> home">
            <img class="brand__mark" src="<?= e($companyLogo) ?>" alt="" width="44" height="44">
            <span class="brand__name"><?= e($companyName) ?></span>
        </a>
        <nav class="site-nav" id="primary-navigation" aria-label="Main navigation">
            <a href="/" aria-current="page">Home</a>
            <a href="/about.php">About</a>
            <a href="/services.php">Services</a>
            <a href="/projects.php">Projects</a>
            <a href="/blog.php">Insights</a>
            <a href="/contact.php">Contact</a>
            <a class="site-nav__cta btn btn--primary" href="/quote.php">Request a Quote <span aria-hidden="true">↗</span></a>
        </nav>
        <button class="site-nav__toggle btn btn--outline" type="button" aria-expanded="false" aria-controls="mobile-menu" aria-label="Toggle navigation menu">
            <span class="site-nav__toggle-icon" aria-hidden="true"></span>
        </button>
    </div>
    <div class="mobile-menu-overlay" id="mobile-menu-overlay"></div>
    <nav class="mobile-menu" id="mobile-menu" aria-label="Mobile navigation">
        <div class="mobile-menu__header">
            <a class="brand" href="/" aria-label="<?= e($companyName) ?> home">
                <img class="brand__mark" src="<?= e($companyLogo) ?>" alt="" width="36" height="36">
                <span class="brand__name"><?= e($companyName) ?></span>
            </a>
            <button class="mobile-menu__close" aria-label="Close menu">
                <span aria-hidden="true">×</span>
            </button>
        </div>
        <ul class="mobile-menu__list">
            <li><a href="/" aria-current="page">Home</a></li>
            <li><a href="/about.php">About</a></li>
            <li><a href="/services.php">Services</a></li>
            <li><a href="/projects.php">Projects</a></li>
            <li><a href="/blog.php">Insights</a></li>
            <li><a href="/contact.php">Contact</a></li>
            <li class="mobile-menu__cta"><a class="btn btn--primary" href="/quote.php">Request a Quote <span aria-hidden="true">↗</span></a></li>
        </ul>
        <div class="mobile-menu__contact">
            <?php if ($navigationPhoneHref !== ''): ?>
                <a href="<?= e($navigationPhoneHref) ?>" class="mobile-contact-item"><?= e(company_phone_display()) ?></a>
            <?php endif; ?>
            <?php if ($navigationEmail !== ''): ?>
                <a href="mailto:<?= e($navigationEmail) ?>" class="mobile-contact-item"><?= e($navigationEmail) ?></a>
            <?php endif; ?>
            <?php if ($navigationWhatsapp !== ''): ?>
                <a href="<?= e($navigationWhatsapp) ?>" target="_blank" rel="noopener noreferrer" class="mobile-contact-item mobile-contact-item--whatsapp">WhatsApp us <span aria-hidden="true">↗</span></a>
            <?php endif; ?>
        </div>
    </nav>
</header>
