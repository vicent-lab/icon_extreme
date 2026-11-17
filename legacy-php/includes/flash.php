<?php

declare(strict_types=1);

function add_flash_message(string $type, string $message): void
{
    if (!in_array($type, ['success', 'error', 'info'], true)) {
        throw new InvalidArgumentException('Unsupported flash message type.');
    }

    $_SESSION['flash_messages'][] = [
        'type' => $type,
        'message' => $message,
    ];
}

function take_flash_messages(): array
{
    $messages = $_SESSION['flash_messages'] ?? [];
    unset($_SESSION['flash_messages']);

    return $messages;
}
