<?php
declare(strict_types=1);
require dirname(__DIR__) . '/config/bootstrap.php';
$name = $argv[1] ?? 'Admin';
$email = $argv[2] ?? 'admin@icon.local';
$password = $argv[3] ?? '';
$role = $argv[4] ?? 'admin';
if ($password === '' || strlen($password) < 12) { fwrite(STDERR, "Password must be at least 12 characters.\n"); exit(1); }
if (!in_array($role, ['admin','editor','support'], true)) { fwrite(STDERR, "Invalid role.\n"); exit(1); }
if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) { fwrite(STDERR, "Invalid email.\n"); exit(1); }
$pdo = db();
$stmt = $pdo->prepare('INSERT INTO admins (name,email,password_hash,role,is_active) VALUES (:name,:email,:hash,:role,1) ON DUPLICATE KEY UPDATE name=VALUES(name), password_hash=VALUES(password_hash), role=VALUES(role), is_active=1');
$stmt->execute(['name'=>$name,'email'=>strtolower($email),'hash'=>password_hash($password,PASSWORD_DEFAULT),'role'=>$role]);
echo "admin-ready\n";
