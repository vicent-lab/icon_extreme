<?php

declare(strict_types=1);

function form_csrf_token(string $form): string
{
    if (!isset($_SESSION['form_csrf'][$form]) || !is_string($_SESSION['form_csrf'][$form])) {
        $_SESSION['form_csrf'][$form] = bin2hex(random_bytes(32));
    }

    return $_SESSION['form_csrf'][$form];
}

function verify_form_csrf(string $form, mixed $token): bool
{
    $expected = $_SESSION['form_csrf'][$form] ?? null;

    return is_string($expected)
        && is_string($token)
        && $token !== ''
        && hash_equals($expected, $token);
}

function clear_form_csrf(string $form): void
{
    unset($_SESSION['form_csrf'][$form]);
}

function clean_form_value(mixed $value): string
{
    if (!is_string($value)) {
        return '';
    }

    $value = str_replace(["\r\n", "\r"], "\n", trim($value));
    $cleaned = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', strip_tags($value));

    return $cleaned === null ? '' : trim($cleaned);
}

function valid_form_length(string $value, int $minimum, int $maximum): bool
{
    $length = function_exists('mb_strlen') ? mb_strlen($value, 'UTF-8') : strlen($value);

    return $length >= $minimum && $length <= $maximum;
}

function normalize_uganda_phone(string $phone): ?string
{
    $phone = preg_replace('/[\s().-]/', '', trim($phone));

    if (!is_string($phone)) {
        return null;
    }

    if (str_starts_with($phone, '+256')) {
        $nationalNumber = substr($phone, 4);
    } elseif (str_starts_with($phone, '256')) {
        $nationalNumber = substr($phone, 3);
    } elseif (str_starts_with($phone, '0')) {
        $nationalNumber = substr($phone, 1);
    } else {
        return null;
    }

    if (!preg_match('/^[237]\d{8}$/', $nationalNumber)) {
        return null;
    }

    return '+256' . $nationalNumber;
}

function form_submission_started_at(): int
{
    return time();
}

function valid_form_submission_time(mixed $startedAt): bool
{
    if (!is_string($startedAt) && !is_int($startedAt)) {
        return false;
    }

    $startedAt = filter_var($startedAt, FILTER_VALIDATE_INT);

    return $startedAt !== false
        && $startedAt <= time()
        && $startedAt >= time() - 86400
        && time() - $startedAt >= 3;
}

function form_is_rate_limited(string $form): bool
{
    $now = time();
    $recentSubmissions = $_SESSION['form_submissions'][$form] ?? [];

    if (!is_array($recentSubmissions)) {
        $recentSubmissions = [];
    }

    $recentSubmissions = array_values(array_filter(
        $recentSubmissions,
        static fn (mixed $timestamp): bool => is_int($timestamp) && $timestamp > $now - 3600
    ));
    $_SESSION['form_submissions'][$form] = $recentSubmissions;

    return count($recentSubmissions) >= 4;
}

function record_form_submission(string $form): void
{
    $_SESSION['form_submissions'][$form][] = time();
}

function phone_pattern(): string
{
    return '(?:\\+?256|0)[\\s.\\(\\)\\-]*[237](?:[\\s.\\(\\)\\-]*[0-9]){8}';
}

function form_flash_messages(): array
{
    return take_flash_messages();
}

function process_quote_form(string $target = 'quote'): array
{
    $errors = [];
    $data = [];

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        return ['errors' => ['Invalid request method.'], 'data' => []];
    }

    // Honeypot: real people never fill this hidden field. Pretend success so bots learn nothing.
    if (clean_form_value($_POST['company_website'] ?? '') !== '') {
        return ['errors' => [], 'data' => [], 'success' => true];
    }

    if (!verify_form_csrf('quote_form', $_POST['csrf_token'] ?? null)) {
        $errors[] = 'The form could not be verified. Please reload the page and try again.';
        return ['errors' => $errors, 'data' => []];
    }

    if (!valid_form_submission_time($_POST['form_started_at'] ?? null)) {
        $errors[] = 'The form submission timed out. Please reload the page and try again.';
        return ['errors' => $errors, 'data' => []];
    }

    if (form_is_rate_limited('quote_form')) {
        $errors[] = 'Too many submissions. Please try again later.';
        return ['errors' => $errors, 'data' => []];
    }

    $fields = [
        'full_name' => ['label' => 'Full name', 'min' => 2, 'max' => 160, 'required' => true],
        'email' => ['label' => 'Email address', 'min' => 5, 'max' => 190, 'required' => true, 'email' => true],
        'phone' => ['label' => 'Phone number', 'min' => 9, 'max' => 40, 'required' => true, 'phone' => true],
        'location' => ['label' => 'Project location', 'min' => 3, 'max' => 180, 'required' => true],
        'project_type' => ['label' => 'Project type', 'min' => 1, 'max' => 160, 'required' => true],
        'budget' => ['label' => 'Estimated budget', 'min' => 0, 'max' => 255, 'required' => false, 'number' => true],
        'message' => ['label' => 'Project description', 'min' => 20, 'max' => 5000, 'required' => true],
        'contact_method' => ['label' => 'Preferred contact method', 'min' => 1, 'max' => 50, 'required' => true],
    ];

    foreach ($fields as $name => $field) {
        $value = clean_form_value($_POST[$name] ?? '');

        if ($field['required'] && $value === '') {
            $errors[$name] = $field['label'] . ' is required.';
            continue;
        }

        if ($value !== '') {
            if ($field['email'] ?? false) {
                if (filter_var($value, FILTER_VALIDATE_EMAIL) === false) {
                    $errors[$name] = 'Enter a valid email address.';
                }
            }

            if ($field['phone'] ?? false) {
                $normalized = normalize_uganda_phone($value);
                if ($normalized === null) {
                    $errors[$name] = 'Enter a valid Ugandan phone number (e.g. 0772 123 456).';
                } else {
                    $value = $normalized;
                }
            }

            if ($field['number'] ?? false) {
                if (!ctype_digit($value)) {
                    $errors[$name] = 'Enter a valid number.';
                }
            }

            if (!valid_form_length($value, $field['min'], $field['max'])) {
                $errors[$name] = $field['label'] . ' must be between ' . $field['min'] . ' and ' . $field['max'] . ' characters.';
            }
        }

        $data[$name] = $value;
    }

    if ($errors !== []) {
        return ['errors' => $errors, 'data' => $data];
    }

    try {
        $connection = db();

        if ($target === 'contact') {
            // Contact page -> contact_messages (it used to land in quote_requests by mistake).
            $body = $data['message']
                . "\n\n— Location: " . $data['location']
                . ($data['budget'] !== '' ? "\n— Budget (UGX): " . $data['budget'] : '')
                . "\n— Preferred contact: " . $data['contact_method'];
            $statement = $connection->prepare(
                'INSERT INTO contact_messages (full_name, email, phone, subject, message)
                 VALUES (:full_name, :email, :phone, :subject, :message)'
            );
            $statement->execute([
                'full_name' => $data['full_name'],
                'email' => $data['email'],
                'phone' => $data['phone'],
                'subject' => $data['project_type'],
                'message' => $body,
            ]);
            record_form_submission('quote_form');
            clear_form_csrf('quote_form');

            return ['errors' => [], 'data' => [], 'success' => true];
        }

        $statement = $connection->prepare(
            'INSERT INTO quote_requests (full_name, email, phone, location, project_type, estimated_budget, project_description, preferred_contact_method)
             VALUES (:full_name, :email, :phone, :location, :project_type, :budget, :message, :contact_method)'
        );
        $statement->execute([
            'full_name' => $data['full_name'],
            'email' => $data['email'],
            'phone' => $data['phone'],
            'location' => $data['location'],
            'project_type' => $data['project_type'],
            'budget' => $data['budget'] !== '' ? (float) $data['budget'] : null,
            'message' => $data['message'],
            'contact_method' => $data['contact_method'],
        ]);

        record_form_submission('quote_form');
        clear_form_csrf('quote_form');

        return ['errors' => [], 'data' => [], 'success' => true];
    } catch (PDOException | RuntimeException $error) {
        error_log('ICON quote submission failed: ' . $error->getMessage());
        $errors[] = 'The quote request could not be submitted. Please try again later.';
        return ['errors' => $errors, 'data' => $data];
    }
}
