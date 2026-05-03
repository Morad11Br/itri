create table if not exists fragrances (
  id uuid primary key default gen_random_uuid(),
  source_id text unique,
  source_url text,
  name text not null,
  brand text not null,
  country text,
  image_url text,
  fallback_image_url text,
  year integer,
  gender text,
  rating numeric,
  rating_votes integer,
  reviews_count integer,
  description text,
  accords jsonb,
  notes jsonb,
  perfumers jsonb,
  popularity_score numeric,
  created_at timestamptz default now()
);

create index if not exists fragrances_popularity_idx
on fragrances (popularity_score desc);

create index if not exists fragrances_brand_idx
on fragrances (brand);

create index if not exists fragrances_rating_idx
on fragrances (rating desc, rating_votes desc);

create index if not exists fragrances_year_idx
on fragrances (year desc);

create table if not exists user_collections (
  user_id uuid not null references auth.users (id) on delete cascade,
  perfume_id text not null references fragrances (source_id) on delete cascade,
  status text not null check (status in ('owned', 'wish', 'tested')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (user_id, perfume_id)
);

create index if not exists user_collections_user_status_idx
on user_collections (user_id, status);

create index if not exists user_collections_perfume_idx
on user_collections (perfume_id);

alter table user_collections enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_collections'
      and policyname = 'Users can read their own collections'
  ) then
    create policy "Users can read their own collections"
    on user_collections for select
    using (auth.uid() = user_id);
  end if;
end $$;

create table if not exists users (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_initials text,
  bio text,
  followers_count integer not null default 0,
  following_count integer not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  perfume_id text not null references fragrances (source_id) on delete cascade,
  rating integer check (rating between 1 and 5),
  longevity integer check (longevity between 1 and 5),
  sillage integer check (sillage between 1 and 5),
  body text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index if not exists reviews_user_perfume_idx
on reviews (user_id, perfume_id);

create index if not exists reviews_perfume_idx
on reviews (perfume_id);

create index if not exists reviews_user_created_idx
on reviews (user_id, created_at desc);

create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  perfume_id text references fragrances (source_id) on delete set null,
  content text not null,
  longevity integer check (longevity between 1 and 5),
  sillage integer check (sillage between 1 and 5),
  likes_count integer not null default 0,
  comments_count integer not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists posts_created_idx
on posts (created_at desc);

create index if not exists posts_user_created_idx
on posts (user_id, created_at desc);

create index if not exists posts_perfume_idx
on posts (perfume_id);

alter table users enable row level security;
alter table reviews enable row level security;
alter table posts enable row level security;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, display_name, avatar_initials)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1), 'Itri User'),
    substring(coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1), 'BU') from 1 for 2)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users are publicly readable'
  ) then
    create policy "Users are publicly readable"
    on users for select
    using (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users can insert own profile'
  ) then
    create policy "Users can insert own profile"
    on users for insert
    with check (auth.uid() = id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users can update own profile'
  ) then
    create policy "Users can update own profile"
    on users for update
    using (auth.uid() = id)
    with check (auth.uid() = id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reviews'
      and policyname = 'Reviews are publicly readable'
  ) then
    create policy "Reviews are publicly readable"
    on reviews for select
    using (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reviews'
      and policyname = 'Users can insert own reviews'
  ) then
    create policy "Users can insert own reviews"
    on reviews for insert
    with check (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reviews'
      and policyname = 'Users can update own reviews'
  ) then
    create policy "Users can update own reviews"
    on reviews for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reviews'
      and policyname = 'Users can delete own reviews'
  ) then
    create policy "Users can delete own reviews"
    on reviews for delete
    using (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'posts'
      and policyname = 'Posts are publicly readable'
  ) then
    create policy "Posts are publicly readable"
    on posts for select
    using (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'posts'
      and policyname = 'Users can insert own posts'
  ) then
    create policy "Users can insert own posts"
    on posts for insert
    with check (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'posts'
      and policyname = 'Users can update own posts'
  ) then
    create policy "Users can update own posts"
    on posts for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'posts'
      and policyname = 'Users can delete own posts'
  ) then
    create policy "Users can delete own posts"
    on posts for delete
    using (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_collections'
      and policyname = 'Users can insert their own collections'
  ) then
    create policy "Users can insert their own collections"
    on user_collections for insert
    with check (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_collections'
      and policyname = 'Users can update their own collections'
  ) then
    create policy "Users can update their own collections"
    on user_collections for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_collections'
      and policyname = 'Users can delete their own collections'
  ) then
    create policy "Users can delete their own collections"
    on user_collections for delete
    using (auth.uid() = user_id);
  end if;
end $$;
