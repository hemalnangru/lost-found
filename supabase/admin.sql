-- Admin dashboard: who is an admin, and the numbers the dashboard shows.
-- Run in Supabase -> SQL Editor.

create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

alter table admins enable row level security;
-- no policies on purpose: nobody can read or edit this table from the app

create or replace function is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;

grant execute on function is_admin() to authenticated;

create or replace function admin_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'Admins only';
  end if;

  return jsonb_build_object(
    'totals', (
      select jsonb_build_object(
        'reports', count(*),
        'lost', count(*) filter (where type = 'lost'),
        'found', count(*) filter (where type = 'found'),
        'open', count(*) filter (where status = 'open'),
        'matched', count(*) filter (where status = 'matched'),
        'claimed', count(*) filter (where status = 'claimed'),
        'returned', count(*) filter (where status = 'returned')
      ) from items
    ),
    'users', (select count(*) from auth.users),
    'conversations', (select count(*) from conversations),
    'messages', (select count(*) from messages),
    'per_day', (
      select coalesce(
        jsonb_agg(jsonb_build_object('day', d.day, 'lost', d.lost, 'found', d.found) order by d.day),
        '[]'::jsonb
      )
      from (
        select to_char(g::date, 'YYYY-MM-DD') as day,
               count(i.id) filter (where i.type = 'lost') as lost,
               count(i.id) filter (where i.type = 'found') as found
        from generate_series(current_date - 29, current_date, interval '1 day') as g
        left join items i on i.event_date = g::date
        group by g
      ) d
    ),
    'by_category', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object('category', c.category, 'lost', c.lost, 'found', c.found)
          order by c.total desc
        ),
        '[]'::jsonb
      )
      from (
        select category,
               count(*) filter (where type = 'lost') as lost,
               count(*) filter (where type = 'found') as found,
               count(*) as total
        from items
        group by category
      ) c
    ),
    'top_cities', (
      select coalesce(
        jsonb_agg(jsonb_build_object('city', t.city, 'total', t.total) order by t.total desc),
        '[]'::jsonb
      )
      from (
        select initcap(lower(trim(city))) as city, count(*) as total
        from items
        where city is not null and trim(city) <> ''
        group by 1
        order by 2 desc
        limit 8
      ) t
    ),
    'points', (
      select coalesce(
        jsonb_agg(jsonb_build_object('id', p.id, 'lat', p.lat, 'lng', p.lng, 'type', p.type, 'title', p.title)),
        '[]'::jsonb
      )
      from (
        select id, lat, lng, type, title
        from items
        where lat is not null and lng is not null
        order by created_at desc
        limit 300
      ) p
    )
  );
end $$;

grant execute on function admin_stats() to authenticated;

-- Make yourself an admin (change the email, then run this line once):
-- insert into admins (user_id) select id from auth.users where email = 'you@example.com' on conflict do nothing;
