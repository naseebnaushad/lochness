-- Invite links so people can join a circle without knowing anyone's UUID.
-- A code is reusable (many people can join with the same code) until it is
-- explicitly revoked or its expiry passes; it can also carry an optional
-- max-uses cap.

create table public.circle_invites (
  id uuid primary key default uuid_generate_v4(),
  circle_id uuid not null references public.circles (id) on delete cascade,
  code text not null unique,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  -- null expires_at means the invite never expires on its own
  expires_at timestamptz,
  revoked_at timestamptz,
  -- null max_uses means unlimited joins
  max_uses integer,
  use_count integer not null default 0
);

create index circle_invites_circle_id_idx on public.circle_invites (circle_id);

-- Generates a short, unambiguous code (no 0/O/1/I) and retries on collision.
create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  candidate text;
begin
  loop
    candidate := (
      select string_agg(substr(alphabet, (ceil(random() * length(alphabet)))::int, 1), '')
      from generate_series(1, 8)
    );
    exit when not exists (select 1 from public.circle_invites where code = candidate);
  end loop;
  return candidate;
end;
$$;

alter table public.circle_invites
  alter column code set default public.generate_invite_code();

alter table public.circle_invites enable row level security;

create policy "members read circle invites" on public.circle_invites
  for select using (public.is_circle_member(circle_id));

create policy "members create circle invites" on public.circle_invites
  for insert with check (
    public.is_circle_member(circle_id) and created_by = auth.uid()
  );

create policy "creator or owner revokes invite" on public.circle_invites
  for update using (
    created_by = auth.uid()
    or exists (select 1 from public.circles c where c.id = circle_id and c.owner_id = auth.uid())
  );

-- Joins the calling user to the circle behind `invite_code`, validating
-- expiry/revocation/use-count server-side so the client never needs insert
-- access to circle_members directly. security definer lets it bypass the
-- owner-only circle_members RLS policy for this one controlled path.
create or replace function public.accept_circle_invite(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  invite public.circle_invites;
begin
  select * into invite
  from public.circle_invites
  where code = upper(invite_code)
  for update;

  if invite is null then
    raise exception 'Invite code not found';
  end if;

  if invite.revoked_at is not null then
    raise exception 'This invite has been revoked';
  end if;

  if invite.expires_at is not null and invite.expires_at <= now() then
    raise exception 'This invite has expired';
  end if;

  if invite.max_uses is not null and invite.use_count >= invite.max_uses then
    raise exception 'This invite has reached its use limit';
  end if;

  insert into public.circle_members (circle_id, user_id, role)
  values (invite.circle_id, auth.uid(), 'member')
  on conflict (circle_id, user_id) do nothing;

  update public.circle_invites
  set use_count = use_count + 1
  where id = invite.id;

  return invite.circle_id;
end;
$$;

grant execute on function public.accept_circle_invite(text) to authenticated;
