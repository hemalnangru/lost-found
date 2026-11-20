-- Pan-India Lost & Found: full database setup
-- Run in Supabase -> SQL Editor on a fresh project.

create extension if not exists vector;

-- 1. Items
create table if not exists items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  type text not null check (type in ('lost','found')),
  title text not null,
  description text,
  category text not null,
  color text,
  city text,
  lat double precision,
  lng double precision,
  event_date date not null,
  image_url text,
  verification_hint text,
  status text default 'open'
    check (status in ('open','matched','claimed','returned')),
  text_embedding vector(384),
  created_at timestamptz default now()
);

alter table items enable row level security;

drop policy if exists "anyone can view items" on items;
drop policy if exists "users add own items" on items;
drop policy if exists "owner updates own items" on items;
drop policy if exists "owner deletes own items" on items;

create policy "anyone can view items" on items
  for select using (true);
create policy "users add own items" on items
  for insert to authenticated with check (auth.uid() = user_id);
create policy "owner updates own items" on items
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner deletes own items" on items
  for delete to authenticated using (auth.uid() = user_id);

-- 2. Matching function (hard filters, then cosine similarity)
drop function if exists match_items(vector, text, text, date, int);

create or replace function match_items(
  query_embedding vector(384),
  item_type text,
  item_category text,
  min_date date,
  match_count int default 10
)
returns table (id uuid, title text, description text, color text,
               city text, lat double precision, lng double precision,
               event_date date, image_url text, similarity float)
language sql stable as $$
  select id, title, description, color, city, lat, lng, event_date, image_url,
         1 - (text_embedding <=> query_embedding) as similarity
  from items
  where type = item_type
    and category = item_category
    and status = 'open'
    and event_date >= min_date
    and text_embedding is not null
  order by text_embedding <=> query_embedding
  limit match_count;
$$;

-- 3. Claim verification (secrets are never readable from the browser)
create table if not exists item_secrets (
  item_id uuid primary key references items(id) on delete cascade,
  question text not null,
  answer text not null,
  contact text not null
);

alter table item_secrets enable row level security;

drop policy if exists "owner adds secret" on item_secrets;
create policy "owner adds secret" on item_secrets
  for insert to authenticated
  with check (exists (
    select 1 from items i where i.id = item_id and i.user_id = auth.uid()
  ));
-- no select policy: nobody can read this table directly

create or replace function get_claim_question(p_item uuid)
returns text language sql security definer set search_path = public as $$
  select question from item_secrets where item_id = p_item;
$$;

create or replace function verify_claim(p_item uuid, p_answer text)
returns text language plpgsql security definer set search_path = public as $$
declare s item_secrets%rowtype;
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  select * into s from item_secrets where item_id = p_item;
  if not found then
    return null;
  end if;
  if length(trim(p_answer)) >= 2 and (
       lower(trim(p_answer)) = lower(trim(s.answer))
    or position(lower(trim(s.answer)) in lower(p_answer)) > 0
  ) then
    return s.contact;
  end if;
  return null;
end $$;

grant execute on function get_claim_question(uuid) to anon, authenticated;
grant execute on function verify_claim(uuid, text) to authenticated;

-- 4. Image storage
insert into storage.buckets (id, name, public)
values ('item-images', 'item-images', true)
on conflict (id) do update set public = true;

drop policy if exists "public read item images" on storage.objects;
drop policy if exists "logged in upload item images" on storage.objects;

create policy "public read item images" on storage.objects
  for select using (bucket_id = 'item-images');
create policy "logged in upload item images" on storage.objects
  for insert to authenticated with check (bucket_id = 'item-images');