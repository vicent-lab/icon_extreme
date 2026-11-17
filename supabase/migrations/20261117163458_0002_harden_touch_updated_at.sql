-- Pin the search_path so the trigger function can't be tricked into using another schema.
alter function private.touch_updated_at() set search_path = '';
