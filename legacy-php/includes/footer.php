<?php
$footerWhatsapp = company_whatsapp_href();
$footerCompanyName = company_setting('company_name');
$footerLogo = company_asset_href('company_logo');
$footerSocialLinks = [
    'Facebook' => company_social_href('company_facebook_url'),
    'Instagram' => company_social_href('company_instagram_url'),
    'LinkedIn' => company_social_href('company_linkedin_url'),
];
$footerPhone = company_phone_display();
$footerEmail = company_setting('company_email');
$footerAddress = company_setting('company_address');
$footerBusinessHours = company_setting('company_business_hours');
?>
<footer class="site-footer">
    <div class="site-footer__main">
        <div class="footer-column footer-brand">
            <a class="brand brand--footer" href="/" aria-label="<?= e($footerCompanyName) ?> home">
                <img class="brand__mark" src="<?= e($footerLogo) ?>" alt="" width="40" height="40">
                <span class="brand__name"><?= e($footerCompanyName) ?></span>
            </a>
            <p><?= e(company_setting('company_tagline')) ?></p>
            <div class="footer-social">
                <?php if ($footerWhatsapp !== ''): ?>
                    <a href="<?= e($footerWhatsapp) ?>" target="_blank" rel="noopener noreferrer" aria-label="WhatsApp">💬</a>
                <?php endif; ?>
                <?php foreach ($footerSocialLinks as $label => $href): ?>
                    <?php if ($href !== ''): ?><a href="<?= e($href) ?>" target="_blank" rel="noopener noreferrer" aria-label="<?= e($label) ?>"><?= strtoupper(substr($label, 0, 1)) ?></a><?php endif; ?>
                <?php endforeach; ?>
            </div>
        </div>
        <div class="footer-column footer-links-col">
            <h4>Quick Links</h4>
            <ul class="footer-links">
                <li><a href="/about.php">About</a></li>
                <li><a href="/services.php">Services</a></li>
                <li><a href="/projects.php">Projects</a></li>
                <li><a href="/blog.php">Insights</a></li>
                <li><a href="/contact.php">Contact</a></li>
            </ul>
        </div>
        <div class="footer-column footer-services-col">
            <h4>Core Services</h4>
            <ul class="footer-links">
                <li><a href="/service.php?slug=building-construction">Building Construction</a></li>
                <li><a href="/service.php?slug=civil-works">Civil Works</a></li>
                <li><a href="/service.php?slug=renovation-remodeling">Renovation</a></li>
                <li><a href="/service.php?slug=road-works">Road Works</a></li>
                <li><a href="/service.php?slug=roofing">Roofing</a></li>
            </ul>
        </div>
        <div class="footer-column footer-contact-col">
            <h4>Contact</h4>
            <ul class="footer-contact">
                <?php if ($footerPhone !== ''): ?>
                    <li class="footer-contact-item">
                        <strong>Phone</strong><br>
                        <a href="<?= e($footerWhatsapp ?: company_phone_href()) ?>"><?= e($footerPhone) ?></a>
                    </li>
                <?php endif; ?>
                <?php if ($footerWhatsapp !== ''): ?>
                    <li class="footer-contact-item">
                        <strong>WhatsApp</strong><br>
                        <a href="<?= e($footerWhatsapp) ?>" target="_blank" rel="noopener noreferrer">WhatsApp us</a>
                    </li>
                <?php endif; ?>
                <?php if ($footerEmail !== ''): ?>
                    <li class="footer-contact-item">
                        <strong>Email</strong><br>
                        <a href="mailto:<?= e($footerEmail) ?>"><?= e($footerEmail) ?></a>
                    </li>
                <?php endif; ?>
                <li class="footer-contact-item">
                    <strong>Location</strong><br>
                    <span><?= e($footerAddress) ?></span>
                </li>
                <?php if ($footerBusinessHours !== ''): ?>
                    <li class="footer-contact-item">
                        <strong>Hours</strong><br>
                        <span><?= e($footerBusinessHours) ?></span>
                    </li>
                <?php endif; ?>
            </ul>
        </div>
    </div>
    <div class="site-footer__bottom">
        <span>&copy; <?= date('Y') ?> <?= e($footerCompanyName) ?>. All rights reserved.</span>
        <span><?= e($footerAddress) ?> <span aria-hidden="true">·</span> <?= e($footerCompanyName) ?></span>
    </div>
</footer>
<?php $footerWhatsapp = company_whatsapp_href(); ?>
<?php if ($footerWhatsapp !== ''): ?>
    <a class="whatsapp-float" href="<?= e($footerWhatsapp) ?>" target="_blank" rel="noopener noreferrer" aria-label="Chat on WhatsApp">
        <span aria-hidden="true">💬</span>
        <span class="whatsapp-float__label">WhatsApp</span>
    </a>
<?php endif; ?>
</body>
</html>
