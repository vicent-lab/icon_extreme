<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

if (!admin_post_token_is_valid()) {
    http_response_code(400);
    exit('The sign-out request could not be verified.');
}

logout_admin();
admin_redirect('login.php');
