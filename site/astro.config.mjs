import { defineConfig } from 'astro/config';

// Plain, ready-made HTML pages: fast on a phone and easy for Google to read.
export default defineConfig({
  site: process.env.SITE_URL || 'https://icon-site-bv6.pages.dev',
  output: 'static',
  build: { inlineStylesheets: 'auto' },
});
