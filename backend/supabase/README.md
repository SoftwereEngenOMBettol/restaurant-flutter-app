# Supabase backend foundation

This folder contains the planned shared backend schema for Caffeine Cafe.

## Current app behaviour

The Flutter application currently stores its orders on the current device with SharedPreferences. The staff dashboard reads and updates that same local order store. It does not yet connect to Supabase, synchronize between devices, authenticate staff, or process online payments.

The SQL below is a backend foundation, not a live connection. It must be applied to a Supabase project, and the Flutter client must be integrated with Supabase Auth, Postgres queries, and Realtime before those capabilities are available.

## Apply the schema

1. Create a Supabase project.
2. Open **SQL Editor → New query**.
3. Copy the full contents of [schema.sql](schema.sql) and run it.
4. Confirm that the `profiles`, `menu_items`, `orders`, and `order_items` tables were created.
5. In **Authentication → Providers**, enable the sign-in method you intend to use.
6. Register a test customer through Supabase Auth. The trigger creates a `customer` profile automatically.
7. To grant a trusted test account staff access, find its Auth user UUID and run this statement in the SQL Editor:

   ```sql
   update public.profiles
   set role = 'staff'
   where id = 'REPLACE-WITH-AUTH-USER-UUID';
   ```

   Use `admin` instead of `staff` only for an administrator you control. Never let a client update its own role.

## Order creation contract

The intended mobile client calls the authenticated RPC:

```sql
select public.place_order(
  'Customer Name',
  '90000000',
  '[
    {"menu_item_id": "MENU-ITEM-UUID", "quantity": 2}
  ]'::jsonb
);
```

The SQL function reads current menu prices on the server and calculates the total; it does not trust a price supplied by the phone. It stores order-item name and price snapshots for historical receipts.

## Security model

- Anonymous users can read active menu items only.
- Authenticated customers can read their own profile, orders, and order items.
- Staff can read restaurant orders and update the order status column only.
- Customers cannot directly insert orders or order items; order creation goes through the price-calculating RPC.
- Profile roles are not writable by the mobile client. Assign staff/admin roles through the trusted Supabase SQL Editor.
- Never include the Supabase `service_role` key in a Flutter app, repository, build argument, or public CI log.

## Remaining integration work

- Add `supabase_flutter` and initialize it with a Supabase project URL and anon/publishable key.
- Add sign-in, sign-up, and sign-out flows.
- Replace local menu data with reads from `menu_items`.
- Implement RPC checkout and fetch orders with their order-item snapshots.
- Subscribe to order changes for staff and customer order tracking.
- Keep local storage as an offline cache/fallback, with explicit sync and conflict behaviour.
- Add integration tests against a dedicated Supabase test project before production use.
