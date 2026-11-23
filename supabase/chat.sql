-- In-app chat between the owner of a report and someone who contacts them.
-- Run in Supabase -> SQL Editor.

create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references items(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  starter_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  unique (item_id, starter_id)
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz default now()
);

create index if not exists messages_conv_idx on messages (conversation_id, created_at);

alter table conversations enable row level security;
alter table messages enable row level security;

-- Only the two people in a conversation can read it
drop policy if exists "participants read conversations" on conversations;
create policy "participants read conversations" on conversations
  for select to authenticated
  using (auth.uid() in (owner_id, starter_id));

drop policy if exists "participants read messages" on messages;
create policy "participants read messages" on messages
  for select to authenticated
  using (exists (
    select 1 from conversations c
    where c.id = conversation_id and auth.uid() in (c.owner_id, c.starter_id)
  ));

-- ...and only they can write, always as themselves
drop policy if exists "participants send messages" on messages;
create policy "participants send messages" on messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from conversations c
      where c.id = conversation_id and auth.uid() in (c.owner_id, c.starter_id)
    )
  );

-- Starting a chat goes through a function, so nobody can invent a conversation
-- with someone else's report
create or replace function start_conversation(p_item uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Log in to send a message';
  end if;
  select user_id into v_owner from items where id = p_item;
  if v_owner is null then
    raise exception 'This report has no owner to message';
  end if;
  if v_owner = auth.uid() then
    raise exception 'This is your own report';
  end if;
  select id into v_id from conversations
    where item_id = p_item and starter_id = auth.uid();
  if v_id is null then
    insert into conversations (item_id, owner_id, starter_id)
      values (p_item, v_owner, auth.uid())
      returning id into v_id;
  end if;
  return v_id;
end $$;

grant execute on function start_conversation(uuid) to authenticated;

-- Live updates for new messages
do $$
begin
  alter publication supabase_realtime add table messages;
exception when duplicate_object then null;
end $$;
