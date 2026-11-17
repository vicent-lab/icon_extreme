<?php

declare(strict_types=1);

function service_icon_svg(string $name): string
{
    $paths = [
        'building' => '<path d="M4 20V4h11v16M15 9h5v11M8 8h3m-3 4h3m-3 4h3m6 0h1m-1-4h1M2 20h20"/>',
        'home' => '<path d="m3 10 9-7 9 7v10H3V10Z"/><path d="M9 20v-6h6v6M2 10h20"/>',
        'commercial' => '<path d="M3 21V5l9-3v19M12 8h9v13M6 8h2m-2 4h2m-2 4h2m6-4h2m-2 4h2m2-4h2m-2 4h2M2 21h20"/>',
        'renovation' => '<path d="m14 6 4-4 4 4-4 4M3 21l3-8L17 2l5 5L11 18l-8 3Z"/><path d="m8 14 3 3"/>',
        'civil' => '<path d="M3 20h18M5 20l2-8h10l2 8M7 12l5-9 5 9M9 8h6"/>',
        'road' => '<path d="M8 21H3l4-18h5l-4 18Zm8 0h5l-4-18h-5l4 18Z"/><path d="m12 4-.5 3m-1 5-.5 3m-1 5-.2 1"/>',
        'roof' => '<path d="m2 11 10-8 10 8M5 10v10h14V10M9 20v-6h6v6M2 21h20"/>',
        'concrete' => '<path d="m4 7 8-4 8 4-8 4-8-4Z"/><path d="M4 7v10l8 4 8-4V7m-8 4v10m-8-9 8 4 8-4"/>',
        'plumbing' => '<path d="M4 3v6a4 4 0 0 0 4 4h5a4 4 0 0 1 4 4v1"/><path d="M2 3h4m-2-2v4m9 8v-3m4 3v-3m-2 10a2 2 0 1 0 4 0c0-1.3-2-4-2-4s-2 2.7-2 4Z"/>',
        'electrical' => '<path d="M13 2 4 14h7l-1 8 10-13h-7l1-7Z"/>',
        'painting' => '<path d="M3 3h15v8H3zM6 11v4a3 3 0 0 0 3 3h5m-5-3v6m4-6v6m4-16h2a3 3 0 0 1 3 3v1"/>',
        'site' => '<path d="m3 18 5-5 4 3 8-9M4 21h16M8 13l-2-7h4l2 7m4-2V4h4v5"/>',
    ];

    $path = $paths[$name] ?? $paths['building'];

    return '<svg class="service-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' . $path . '</svg>';
}
