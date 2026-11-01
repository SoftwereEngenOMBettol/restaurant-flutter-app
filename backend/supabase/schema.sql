-- Caffeine Cafe — Supabase schema
-- Apply this file once in the Supabase SQL Editor.
-- Client applications must use the anon/publishable key only. Never ship service_role keys.

create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('customer', 'staff', 'admin');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.order_status as enum ('received', 'preparing', 'ready', 'completed');
exception when duplicate_object then null;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'Customer',
  role public.app_role not null default 'customer',
  created_at timestamptz not null default now()
);

create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  category text not null,
  price_omr numeric(8, 3) not null check (price_omr > 0),
  image_url text,
  is_popular boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete restrict,
  customer_name text not null,
  phone text not null,
  status public.order_status not null default 'received',
  total_omr numeric(10, 3) not null check (total_omr >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id) on delete set null,
  item_name_snapshot text not null,
  quantity integer not null check (quantity between 1 and 20),
  unit_price_omr numeric(8, 3) not null check (unit_price_omr > 0),
  line_total_omr numeric(10, 3)
    generated always as (quantity * unit_price_omr) stored
);

create index if not exists orders_customer_created_idx
  on public.orders(customer_id, created_at desc);
create index if not exists orders_status_created_idx
  on public.orders(status, created_at desc);
create index if not exists order_items_order_idx
  on public.order_items(order_id);

-- Create a customer profile automatically after Supabase Auth sign-up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'Customer')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- SECURITY DEFINER helpers avoid recursive profile RLS checks.
create or replace function public.current_user_is_staff()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role in ('staff', 'admin')
  );
$$;

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
  );
$$;

-- Customers can only place orders through the server-side price-calculating RPC.
-- The client sends menu item IDs and quantities; prices always come from menu_items.
create or replace function public.place_order(
  p_customer_name text,
  p_phone text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order_id uuid;
  v_total numeric(10, 3) := 0;
  v_item jsonb;
  v_menu_item_id uuid;
  v_quantity integer;
  v_item_name text;
  v_unit_price numeric(8, 3);
begin
  if (select auth.uid()) is null then
    raise exception 'You must be signed in to place an order.';
  end if;

  if nullif(trim(p_customer_name), '') is null then
    raise exception 'Customer name is required.';
  end if;

  if length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) < 7 then
    raise exception 'A valid phone number is required.';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Add at least one menu item.';
  end if;

  if jsonb_array_length(p_items) > 30 then
    raise exception 'An order cannot contain more than 30 lines.';
  end if;

  -- Validate every requested item and calculate the authoritative total.
  for v_item in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_menu_item_id := (v_item ->> 'menu_item_id')::uuid;
      v_quantity := (v_item ->> 'quantity')::integer;
    exception when invalid_text_representation then
      raise exception 'Each order line needs a valid menu item ID and quantity.';
    end;

    if v_quantity < 1 or v_quantity > 20 then
      raise exception 'Item quantities must be between 1 and 20.';
    end if;

    select name, price_omr
      into v_item_name, v_unit_price
      from public.menu_items
      where id = v_menu_item_id and is_active = true;

    if not found then
      raise exception 'A selected menu item is no longer available.';
    end if;

    v_total := v_total + (v_unit_price * v_quantity);
  end loop;

  insert into public.orders (
    customer_id, customer_name, phone, status, total_omr
  )
  values (
    (select auth.uid()), trim(p_customer_name), trim(p_phone),
    'received', v_total
  )
  returning id into v_order_id;

  -- Insert price/name snapshots so historical receipts remain unchanged.
  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_menu_item_id := (v_item ->> 'menu_item_id')::uuid;
    v_quantity := (v_item ->> 'quantity')::integer;

    select name, price_omr
      into v_item_name, v_unit_price
      from public.menu_items
      where id = v_menu_item_id and is_active = true;

    insert into public.order_items (
      order_id, menu_item_id, item_name_snapshot, quantity, unit_price_omr
    )
    values (
      v_order_id, v_menu_item_id, v_item_name, v_quantity, v_unit_price
    );
  end loop;

  return v_order_id;
end;
$$;

alter table public.profiles enable row level security;
alter table public.menu_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists "Profiles visible to owner and staff" on public.profiles;
create policy "Profiles visible to owner and staff"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select public.current_user_is_staff()));

drop policy if exists "Owners can update their profile name" on public.profiles;
create policy "Owners can update their profile name"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists "Active menu is public" on public.menu_items;
create policy "Active menu is public"
on public.menu_items for select to anon, authenticated
using (is_active or (select public.current_user_is_staff()));

drop policy if exists "Customers and staff can read permitted orders" on public.orders;
create policy "Customers and staff can read permitted orders"
on public.orders for select to authenticated
using (
  customer_id = (select auth.uid())
  or (select public.current_user_is_staff())
);

drop policy if exists "Staff can update order status" on public.orders;
create policy "Staff can update order status"
on public.orders for update to authenticated
using ((select public.current_user_is_staff()))
with check ((select public.current_user_is_staff()));

drop policy if exists "Customers and staff can read permitted order items" on public.order_items;
create policy "Customers and staff can read permitted order items"
on public.order_items for select to authenticated
using (
  exists (
    select 1
    from public.orders
    where orders.id = order_items.order_id
      and (
        orders.customer_id = (select auth.uid())
        or (select public.current_user_is_staff())
      )
  )
);

-- Grant only the columns each client role needs.
grant usage on schema public to anon, authenticated;
grant select on public.menu_items to anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;
grant select on public.orders to authenticated;
grant update (status) on public.orders to authenticated;
grant select on public.order_items to authenticated;
revoke all on function public.place_order(text, text, jsonb) from public;
grant execute on function public.place_order(text, text, jsonb) to authenticated;

-- Sample menu based on the existing Caffeine Cafe project.
insert into public.menu_items
  (slug, name, description, category, price_omr, image_url, is_popular)
values
  ('americano', 'Americano', 'A smooth double espresso softened with hot water.', 'Espresso', 1.500, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/Americano.jpg', true),
  ('spanish-latte', 'Spanish Latte', 'Rich espresso, silky milk and condensed milk.', 'Latte', 2.300, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/spanishlatte.jpg', true),
  ('pistachio-latte', 'Pistachio Latte', 'Creamy latte with a roasted pistachio finish.', 'Latte', 2.600, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/pistachiolatte.jpg', true),
  ('cold-brew', 'Cold Brew', 'Slow-steeped coffee served chilled.', 'Cold', 2.000, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/coldbrew.jpg', true),
  ('cappuccino', 'Cappuccino', 'Espresso topped with velvety steamed milk foam.', 'Espresso', 1.900, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/cappuccino.jpg', false),
  ('caramel-latte', 'Caramel Latte', 'Espresso and milk finished with buttery caramel.', 'Latte', 2.200, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/caramellatte.jpg', false),
  ('mocha', 'Mocha', 'Espresso blended with chocolate and milk.', 'Latte', 2.100, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/mocha.jpg', false),
  ('rose-latte', 'Rose Latte', 'A fragrant latte with a gentle floral note.', 'Latte', 2.400, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/roselatte.jpg', false),
  ('saffron-latte', 'Saffron Latte', 'A signature latte inspired by saffron.', 'Latte', 2.700, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/saffronlatte.jpg', false),
  ('white-mocha', 'White Mocha', 'Espresso with creamy white chocolate and milk.', 'Latte', 2.300, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/whitemocha.jpg', false),
  ('chemex', 'Chemex', 'A clean, delicate pour-over coffee.', 'Brew', 2.500, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/chemex.jpg', false),
  ('v60', 'V60', 'A carefully extracted pour-over coffee.', 'Brew', 2.200, 'https://raw.githubusercontent.com/SoftwereEngenOMBettol/caffeine-cafe/main/v60.jpg', false)
on conflict (slug) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  price_omr = excluded.price_omr,
  image_url = excluded.image_url,
  is_popular = excluded.is_popular;
