// Reads what the website shows from Supabase, once, when the site is built.
// The public key only sees published rows (the database rules guarantee it), and budgets are never readable.
// If Supabase is unreachable the build still succeeds with empty lists, so a hiccup never takes the site down.

const URL_ = (import.meta.env.PUBLIC_SUPABASE_URL ?? process.env.PUBLIC_SUPABASE_URL ?? 'https://ioktaopzboaremkamwmd.supabase.co').replace(/\/$/, '');
const KEY = import.meta.env.PUBLIC_SUPABASE_ANON_KEY ?? process.env.PUBLIC_SUPABASE_ANON_KEY ?? 'sb_publishable_rqNoDn6qaIfo9pRX2a26Mg_z2aNJhOl';

export const supabaseUrl = URL_;
export const supabaseKey = KEY;
export const appUrl = (import.meta.env.PUBLIC_APP_URL ?? process.env.PUBLIC_APP_URL ?? 'https://icon-extreme.pages.dev').replace(/\/$/, '');

async function get<T>(path: string): Promise<T[]> {
  try {
    const res = await fetch(`${URL_}/rest/v1/${path}`, { headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } });
    if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
    return (await res.json()) as T[];
  } catch (e) {
    console.warn(`[site] could not load ${path.split('?')[0]}:`, (e as Error).message);
    return [];
  }
}

export interface Project {
  id: number; title: string; slug: string; summary: string | null; description: string | null;
  location: string; project_type: string; status: 'upcoming' | 'ongoing' | 'completed' | 'on_hold';
  progress_pct: number; challenge: string | null; solution: string | null; results: string | null;
  featured_image: string | null; is_featured: boolean; start_date: string | null; end_date: string | null;
}
export interface ProjectImage { id: number; project_id: number; image_path: string; alt_text: string | null; caption: string | null }
export interface Service { id: number; name: string; slug: string; short_description: string; full_description: string | null; image_path: string | null; is_featured: boolean }
export interface Testimonial { id: number; client_name: string; client_role: string | null; company: string | null; quote: string; rating: number | null; photo_path: string | null }
export interface TeamMember { id: number; name: string; job_title: string; bio: string | null; image_path: string | null }

const PROJECT_COLS = 'id,title,slug,summary,description,location,project_type,status,progress_pct,challenge,solution,results,featured_image,is_featured,start_date,end_date';

export const getProjects = () => get<Project>(`projects?select=${PROJECT_COLS}&is_published=eq.true&order=is_featured.desc,display_order.asc,created_at.desc`);
export const getProjectImages = (projectId: number) => get<ProjectImage>(`project_images?select=id,project_id,image_path,alt_text,caption&project_id=eq.${projectId}&order=display_order.asc`);
export const getServices = () => get<Service>('services?select=id,name,slug,short_description,full_description,image_path,is_featured&is_active=eq.true&order=display_order.asc');
export const getTestimonials = () => get<Testimonial>('testimonials?select=id,client_name,client_role,company,quote,rating,photo_path&is_published=eq.true&client_permission=eq.true&order=is_featured.desc,display_order.asc&limit=6');
export const getTeam = () => get<TeamMember>('team_members?select=id,name,job_title,bio,image_path&is_active=eq.true&order=display_order.asc');

export async function getSettings(): Promise<Record<string, string>> {
  const rows = await get<{ key: string; value: string | null }>('company_settings?select=key,value&is_public=eq.true');
  return Object.fromEntries(rows.filter((r) => r.value).map((r) => [r.key, r.value as string]));
}

/** Pictures live in the public "site-media" bucket. */
export const mediaUrl = (path: string | null | undefined) =>
  !path ? null : /^https?:\/\//.test(path) ? path : `${URL_}/storage/v1/object/public/site-media/${path}`;

export const statusLabel = (s: string) => ({ completed: 'Completed', ongoing: 'On site now', upcoming: 'Starting soon', on_hold: 'On hold' } as Record<string, string>)[s] ?? s;
