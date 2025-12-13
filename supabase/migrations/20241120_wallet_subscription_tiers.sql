-- Add tier column to users table
alter table auth.users add column if not exists wallet_tier text default 'basic' check (wallet_tier in ('basic', 'pro', 'kingdom'));

-- Create subscriptions table for tracking payments and history
create table subscriptions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  tier text not null check (tier in ('basic', 'pro', 'kingdom')),
  amount decimal(10,2) not null,
  currency text default 'ZMW',
  status text default 'active' check (status in ('active', 'pending', 'expired', 'cancelled')),
  payment_method text check (payment_method in ('airtel', 'mtn')),
  subscription_start timestamp with time zone default now(),
  subscription_end timestamp with time zone,
  last_payment_date timestamp with time zone,
  next_payment_date timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create subscription_payments table for individual payments
create table subscription_payments (
  id uuid default gen_random_uuid() primary key,
  subscription_id uuid references subscriptions(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  amount decimal(10,2) not null,
  currency text default 'ZMW',
  status text default 'pending' check (status in ('pending', 'completed', 'failed')),
  payment_method text check (payment_method in ('airtel', 'mtn')),
  transaction_id text,
  reference text unique,
  payment_date timestamp with time zone default now(),
  created_at timestamp with time zone default now()
);

-- Create tier_changes table for logging upgrades/downgrades
create table tier_changes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  old_tier text check (old_tier in ('basic', 'pro', 'kingdom')),
  new_tier text check (new_tier in ('basic', 'pro', 'kingdom')),
  reason text, -- 'upgrade', 'downgrade', 'payment_failed', 'manual'
  changed_at timestamp with time zone default now(),
  changed_by uuid references auth.users(id) -- null for automatic changes
);

-- Indexes
create index subscriptions_user_id_idx on subscriptions(user_id);
create index subscriptions_status_idx on subscriptions(status);
create index subscriptions_next_payment_date_idx on subscriptions(next_payment_date);
create index subscription_payments_subscription_id_idx on subscription_payments(subscription_id);
create index subscription_payments_status_idx on subscription_payments(status);
create index tier_changes_user_id_idx on tier_changes(user_id);

-- Enable RLS
alter table subscriptions enable row level security;
alter table subscription_payments enable row level security;
alter table tier_changes enable row level security;

-- Policies
create policy "Users can view own subscriptions" on subscriptions
  for select using (auth.uid() = user_id);

create policy "Users can create own subscriptions" on subscriptions
  for insert with check (auth.uid() = user_id);

create policy "Service role can manage subscriptions" on subscriptions
  for all using (auth.role() = 'service_role');

create policy "Users can view own subscription payments" on subscription_payments
  for select using (auth.uid() = user_id);

create policy "Service role can manage subscription payments" on subscription_payments
  for all using (auth.role() = 'service_role');

create policy "Users can view own tier changes" on tier_changes
  for select using (auth.uid() = user_id);

create policy "Service role can manage tier changes" on tier_changes
  for all using (auth.role() = 'service_role');

-- Function to get user tier
create or replace function get_user_tier(p_user_id uuid)
returns text as $$
declare
  user_tier text;
begin
  select coalesce(wallet_tier, 'basic') into user_tier
  from auth.users
  where id = p_user_id;

  return user_tier;
end;
$$ language plpgsql security definer;

-- Function to update user tier
create or replace function update_user_tier(p_user_id uuid, p_new_tier text, p_reason text default 'manual', p_changed_by uuid default null)
returns void as $$
declare
  old_tier text;
begin
  -- Get current tier
  select get_user_tier(p_user_id) into old_tier;

  -- Update user tier
  update auth.users set wallet_tier = p_new_tier where id = p_user_id;

  -- Log the change
  insert into tier_changes (user_id, old_tier, new_tier, reason, changed_by)
  values (p_user_id, old_tier, p_new_tier, p_reason, p_changed_by);
end;
$$ language plpgsql security definer;

-- Function to calculate admin fee based on tier
create or replace function calculate_admin_fee(p_amount decimal, p_user_tier text)
returns decimal as $$
begin
  case p_user_tier
    when 'basic' then return round(p_amount * 0.10, 2);
    when 'pro' then return round(p_amount * 0.05, 2);
    when 'kingdom' then return 0.00;
    else return round(p_amount * 0.10, 2); -- default to basic
  end case;
end;
$$ language plpgsql security definer;