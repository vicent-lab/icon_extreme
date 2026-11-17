<?php

declare(strict_types=1);

require dirname(__DIR__) . '/config/bootstrap.php';

$companyName = company_setting('company_name');
$pageTitle = 'Request a Quote | ' . $companyName;
$pageDescription = 'Request a quote from ICON Construction Company for your building, renovation or civil works project.';
$pageExtraHeadTags = '<link rel="canonical" href="/quote.php">';

$formErrors = [];
$formValues = [];
$quoteSubmitted = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $result = process_quote_form();
    $formErrors = $result['errors'];
    $formValues = $result['data'];
    if (!empty($result['success'])) {
        $quoteSubmitted = true;
    }
}

require PROJECT_ROOT . '/includes/header.php';
?>
<main id="main-content">

    <section class="hero reveal" style="background:linear-gradient(rgba(15, 23, 17, 0.65), rgba(15, 23, 17, 0.65)),url('<?= e(asset('images/site/site-construction-workers.webp')) ?>');background-size:cover;background-position:center;color:#fff;padding-block:80px;">
        <div class="container hero__inner">
            <p class="eyebrow eyebrow--dark reveal reveal-delay-1"><span class="eyebrow__line"></span> <?= e($companyName) ?></p>
            <h1 class="reveal reveal-delay-2" style="color:#fff;">Request a Quote</h1>
            <p class="hero__intro reveal reveal-delay-3" style="color:rgba(255,255,255,0.85);">Tell us about your project. We&rsquo;ll review your requirements and get back to you with next steps.</p>
        </div>
    </section>

<?php if ($quoteSubmitted): ?>
        <section class="quote-form section-pad reveal reveal-delay-1">
            <div class="container">
                <div class="quote-form__card">
                    <div class="quote-success">
                        <span class="quote-success__icon" aria-hidden="true">✓</span>
                        <h2>Quote Request Submitted</h2>
                        <p>Thank you for your enquiry. We&rsquo;ve received your project details and will get back to you soon.</p>
                        <a class="button button--primary" href="/">Return to Homepage <span aria-hidden="true">→</span></a>
                    </div>
                </div>
            </div>
        </section>
    <?php else: ?>
        <section class="quote-form section-pad reveal reveal-delay-1">
            <div class="container">
                <div class="quote-form__card">
                    <?php if ($formErrors !== []): ?>
                        <div class="form-alert form-alert--error" role="alert">
                            <p>Please correct the following errors:</p>
                            <ul>
                                <?php foreach ($formErrors as $error): ?>
                                    <li><?= e($error) ?></li>
                                <?php endforeach; ?>
                            </ul>
                        </div>
                    <?php endif; ?>
                    <form class="business-form" method="post" action="/quote.php">
                        <input type="hidden" name="csrf_token" value="<?= e(form_csrf_token('quote_form')) ?>">
                        <input type="hidden" name="form_started_at" value="<?= e((string) form_submission_started_at()) ?>">
                        <div class="form-honeypot" aria-hidden="true">
                            <label for="quote-company-website">Leave this field empty</label>
                            <input id="quote-company-website" name="company_website" type="text" value="" tabindex="-1" autocomplete="off">
                        </div>

                        <div class="business-form__grid">
                            <div class="form-field<?= isset($formErrors['full_name']) ? ' form-field--error' : '' ?>">
                                <label for="quote-full-name">Full name <span aria-hidden="true">*</span></label>
                                <input id="quote-full-name" name="full_name" type="text" value="<?= e($formValues['full_name'] ?? '') ?>" autocomplete="name" minlength="2" maxlength="160" required<?= isset($formErrors['full_name']) ? ' aria-invalid="true" aria-describedby="quote-full-name-error"' : '' ?>>
                                <?php if (isset($formErrors['full_name'])): ?><span class="form-field__error" id="quote-full-name-error"><?= e($formErrors['full_name']) ?></span><?php endif; ?>
                            </div>
                            <div class="form-field<?= isset($formErrors['email']) ? ' form-field--error' : '' ?>">
                                <label for="quote-email">Email address <span aria-hidden="true">*</span></label>
                                <input id="quote-email" name="email" type="email" value="<?= e($formValues['email'] ?? '') ?>" autocomplete="email" maxlength="190" required<?= isset($formErrors['email']) ? ' aria-invalid="true" aria-describedby="quote-email-error"' : '' ?>>
                                <?php if (isset($formErrors['email'])): ?><span class="form-field__error" id="quote-email-error"><?= e($formErrors['email']) ?></span><?php endif; ?>
                            </div>
                            <div class="form-field<?= isset($formErrors['phone']) ? ' form-field--error' : '' ?>">
                                <label for="quote-phone">Phone number <span aria-hidden="true">*</span></label>
                                <input id="quote-phone" name="phone" type="tel" value="<?= e($formValues['phone'] ?? '') ?>" autocomplete="tel" inputmode="tel" placeholder="0772 123 456" required<?= isset($formErrors['phone']) ? ' aria-invalid="true" aria-describedby="quote-phone-error"' : '' ?>>
                                <span class="form-field__hint" id="quote-phone-hint">Ugandan numbers, e.g. 0772 123 456 or +256 772 123 456.</span>
                                <?php if (isset($formErrors['phone'])): ?><span class="form-field__error" id="quote-phone-error"><?= e($formErrors['phone']) ?></span><?php endif; ?>
                            </div>
                            <div class="form-field form-field--full<?= isset($formErrors['location']) ? ' form-field--error' : '' ?>">
                                <label for="quote-location">Project location <span aria-hidden="true">*</span></label>
                                <input id="quote-location" name="location" type="text" value="<?= e($formValues['location'] ?? '') ?>" placeholder="e.g. Kampala, Wakiso, Jinja" required<?= isset($formErrors['location']) ? ' aria-invalid="true" aria-describedby="quote-location-error"' : '' ?>>
                                <?php if (isset($formErrors['location'])): ?><span class="form-field__error" id="quote-location-error"><?= e($formErrors['location']) ?></span><?php endif; ?>
                            </div>
                            <div class="form-field<?= isset($formErrors['project_type']) ? ' form-field--error' : '' ?>">
                                <label for="quote-project-type">Project type <span aria-hidden="true">*</span></label>
                                <select id="quote-project-type" name="project_type" required<?= isset($formErrors['project_type']) ? ' aria-invalid="true"' : '' ?>>
                                    <option value="">Select a project type</option>
                                    <option value="building-construction"<?= (($formValues['project_type'] ?? '') === 'building-construction') ? ' selected' : '' ?>>Building Construction</option>
                                    <option value="residential-construction"<?= (($formValues['project_type'] ?? '') === 'residential-construction') ? ' selected' : '' ?>>Residential Construction</option>
                                    <option value="commercial-construction"<?= (($formValues['project_type'] ?? '') === 'commercial-construction') ? ' selected' : '' ?>>Commercial Construction</option>
                                    <option value="civil-works"<?= (($formValues['project_type'] ?? '') === 'civil-works') ? ' selected' : '' ?>>Civil Works</option>
                                    <option value="road-works"<?= (($formValues['project_type'] ?? '') === 'road-works') ? ' selected' : '' ?>>Road Works</option>
                                    <option value="renovation-remodeling"<?= (($formValues['project_type'] ?? '') === 'renovation-remodeling') ? ' selected' : '' ?>>Renovation & Remodeling</option>
                                    <option value="roofing"<?= (($formValues['project_type'] ?? '') === 'roofing') ? ' selected' : '' ?>>Roofing</option>
                                    <option value="concrete-works"<?= (($formValues['project_type'] ?? '') === 'concrete-works') ? ' selected' : '' ?>>Concrete Works</option>
                                    <option value="plumbing"<?= (($formValues['project_type'] ?? '') === 'plumbing') ? ' selected' : '' ?>>Plumbing</option>
                                    <option value="electrical-installation"<?= (($formValues['project_type'] ?? '') === 'electrical-installation') ? ' selected' : '' ?>>Electrical Installation</option>
                                    <option value="painting-finishing"<?= (($formValues['project_type'] ?? '') === 'painting-finishing') ? ' selected' : '' ?>>Painting & Finishing</option>
                                    <option value="site-preparation"<?= (($formValues['project_type'] ?? '') === 'site-preparation') ? ' selected' : '' ?>>Site Preparation</option>
                                    <option value="other"<?= (($formValues['project_type'] ?? '') === 'other') ? ' selected' : '' ?>>Other</option>
                                </select>
                                <?php if (isset($formErrors['project_type'])): ?><span class="form-field__error"><?= e($formErrors['project_type']) ?></span><?php endif; ?>
                            </div>
                            <div class="form-field<?= isset($formErrors['budget']) ? ' form-field--error' : '' ?>">
                                <label for="quote-budget">Estimated budget (UGX) <span class="form-field__optional">Optional</span></label>
                                <input id="quote-budget" name="budget" type="text" value="<?= e($formValues['budget'] ?? '') ?>" placeholder="e.g. 50000000"<?= isset($formErrors['budget']) ? ' aria-invalid="true" aria-describedby="quote-budget-error"' : '' ?>>
                                <?php if (isset($formErrors['budget'])): ?><span class="form-field__error" id="quote-budget-error"><?= e($formErrors['budget']) ?></span><?php endif; ?>
                            </div>
                            <div class="form-field form-field--full<?= isset($formErrors['message']) ? ' form-field--error' : '' ?>">
                                <label for="quote-message">Project description <span aria-hidden="true">*</span></label>
                                <textarea id="quote-message" name="message" rows="6" minlength="20" maxlength="5000" required<?= isset($formErrors['message']) ? ' aria-invalid="true" aria-describedby="quote-message-error"' : '' ?>><?= e($formValues['message'] ?? '') ?></textarea>
                                <?php if (isset($formErrors['message'])): ?><span class="form-field__error" id="quote-message-error"><?= e($formErrors['message']) ?></span><?php endif; ?>
                            </div>
                            <div class="form-field form-field--full<?= isset($formErrors['contact_method']) ? ' form-field--error' : '' ?>">
                                <label for="quote-contact-method">Preferred contact method <span aria-hidden="true">*</span></label>
                                <select id="quote-contact-method" name="contact_method" required<?= isset($formErrors['contact_method']) ? ' aria-invalid="true"' : '' ?>>
                                    <option value="phone"<?= (($formValues['contact_method'] ?? '') === 'phone') ? ' selected' : '' ?>>Phone call</option>
                                    <option value="email"<?= (($formValues['contact_method'] ?? '') === 'email') ? ' selected' : '' ?>>Email</option>
                                    <option value="whatsapp"<?= (($formValues['contact_method'] ?? '') === 'whatsapp') ? ' selected' : '' ?>>WhatsApp</option>
                                </select>
                                <?php if (isset($formErrors['contact_method'])): ?><span class="form-field__error"><?= e($formErrors['contact_method']) ?></span><?php endif; ?>
                            </div>
                        </div>
                        <button class="button button--primary business-form__submit" type="submit">Send Request <span aria-hidden="true">→</span></button>
                        <p class="business-form__privacy">Your details are used only to respond to your enquiry.</p>
                    </form>
                </div>
            </div>
        </section>
    <?php endif; ?>
</main>
<?php require PROJECT_ROOT . '/includes/footer.php'; ?>
