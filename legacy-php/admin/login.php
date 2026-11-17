<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

if (is_admin_authenticated()) {
    admin_redirect('');
}

$errorMessage = '';
$databaseUnavailable = false;


$cooldown = (int) ($_SESSION['admin_login_blocked_until'] ?? 0);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!verify_admin_csrf($_POST['csrf_token'] ?? null)) {
        $errorMessage = 'Your login session expired. Refresh the page and try again.';
    } elseif ($cooldown > time()) {
        $errorMessage = 'Too many unsuccessful attempts. Please wait a few minutes before trying again.';
    } else {
        $email = strtolower(admin_input_string($_POST, 'email'));
        $password = is_string($_POST['password'] ?? null) ? $_POST['password'] : '';
        $admin = false;

        try {
            $statement = db()->prepare(
                'SELECT id, name, email, password_hash, role
                FROM admins
                WHERE email = :email AND is_active = 1
                LIMIT 1'
            );
            $statement->execute(['email' => $email]);
            $admin = $statement->fetch();
        } catch (PDOException | RuntimeException $error) {
            error_log('ICON admin login query failed: ' . $error->getMessage());
            $databaseUnavailable = true;
        }

        $passwordValid = false;
        if (is_array($admin)) {
            if (password_verify($password, $admin['password_hash'])) {
                $passwordValid = true;
            }
        }

        if ($databaseUnavailable) {
            http_response_code(503);
            $errorMessage = 'Sign-in is temporarily unavailable. Please try again later.';
        } elseif (is_array($admin) && $passwordValid) {
            if (password_needs_rehash($admin['password_hash'], PASSWORD_DEFAULT)) {
                try {
                    $hash = password_hash($password, PASSWORD_DEFAULT);
                    $update = db()->prepare('UPDATE admins SET password_hash = :hash WHERE id = :id');
                    $update->execute(['hash' => $hash, 'id' => $admin['id']]);
                } catch (PDOException | RuntimeException $error) {
                    error_log('ICON admin password rehash failed: ' . $error->getMessage());
                }
            }

            login_admin($admin);
            unset($_SESSION['admin_login_attempts'], $_SESSION['admin_login_blocked_until']);
            $_SESSION['admin_csrf'] = bin2hex(random_bytes(32));
            admin_redirect('');
        }

        if (!$databaseUnavailable) {
            {
                $attempts = (int) ($_SESSION['admin_login_attempts'] ?? 0) + 1;
                $_SESSION['admin_login_attempts'] = $attempts;

                if ($attempts >= 5) {
                    $_SESSION['admin_login_attempts'] = 0;
                    $_SESSION['admin_login_blocked_until'] = time() + 300;
                }
            }

            $errorMessage = 'The email or password was not recognized.';
        }
    }
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>Administrator sign in | <?= e(company_setting('company_name')) ?></title>
    <link rel="icon" href="<?= e(company_asset_href('company_favicon')) ?>">
    <link rel="stylesheet" href="/assets/css/admin.css">
</head>
<body class="admin-login">
    <main class="login-card">
        <a class="admin-brand admin-brand--login" href="/">
            <img class="admin-brand__logo" src="<?= e(company_asset_href('company_logo')) ?>" alt="">
            <span><?= e(company_setting('company_name')) ?></span>
        </a>
        <p class="admin-eyebrow">Secure workspace</p>
        <h1>Administrator sign in</h1>
        <p class="login-card__intro">Sign in with your company administrator account.</p>
        <?php if ($errorMessage !== ''): ?><div class="admin-alert admin-alert--error" role="alert"><?= e($errorMessage) ?></div><?php endif; ?>
        <form method="post" action="/admin/login.php">
            <input type="hidden" name="csrf_token" value="<?= e(admin_csrf_token()) ?>">
            <label for="email">Email address</label>
            <input id="email" name="email" type="email" maxlength="190" autocomplete="username" value="" required>
            <label for="password">Password</label>
            <input id="password" name="password" type="password" autocomplete="current-password" value="" required>
            <div style="margin: 8px 0 14px; display: flex; align-items: center; gap: 8px; font-size: 13px;">
                <input type="checkbox" id="togglePassword" onclick="const p = document.getElementById('password'); p.type = this.checked ? 'text' : 'password';">
                <label for="togglePassword" style="margin: 0; font-weight: normal; cursor: pointer;">Show password</label>
            </div>
            <button class="admin-button admin-button--primary admin-button--full" type="submit">Sign in</button>
        </form>
        <a class="login-card__back" href="/">← Back to website</a>
    </main>
</body>
</html>
