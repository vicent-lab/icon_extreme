import { getProjects } from '../lib/data';

export async function GET({ site }: { site: URL }) {
  const base = site.toString().replace(/\/$/, '');
  const projects = await getProjects();
  const urls = ['/', ...projects.map((p) => `/projects/${p.slug}/`)];
  const body = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map((u) => `  <url><loc>${base}${u}</loc></url>`).join('\n')}\n</urlset>\n`;
  return new Response(body, { headers: { 'Content-Type': 'application/xml' } });
}
