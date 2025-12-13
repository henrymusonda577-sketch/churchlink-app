-- Create wallets table
create table wallets (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  balance decimal(10,2) default 0.00 check (balance >= 0),
  currency text default 'ZMW',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create transactions table
create table transactions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  type text not null check (type in ('send', 'receive')),
  amount decimal(10,2) not null check (amount > 0),
  currency text default 'ZMW',
  status text default 'pending' check (status in ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  reference text unique not null,
  provider text not null check (provider in ('airtel', 'mtn')),
  external_id text,
  description text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Indexes
create index wallets_user_id_idx on wallets(user_id);
create index transactions_user_id_idx on transactions(user_id);
create index transactions_reference_idx on transactions(reference);
create index transactions_status_idx on transactions(status);

-- Enable RLS
alter table wallets enable row level security;
alter table transactions enable row level security;

-- Policies for wallets
create policy "Users can view own wallet" on wallets
  for select using (auth.uid() = user_id);

create policy "Service role can manage wallets" on wallets
  for all using (auth.role() = 'service_role');

-- Policies for transactions
create policy "Users can view own transactions" on transactions
  for select using (auth.uid() = user_id);

create policy "Service role can manage transactions" on transactions
  for all using (auth.role() = 'service_role');

-- Function to update wallet balance
create or replace function update_wallet_balance(p_user_id uuid, p_amount decimal, p_type text)
returns void as $$
begin
  if p_type = 'receive' then
    update wallets set balance = balance + p_amount, updated_at = now() where user_id = p_user_id;
  elsif p_type = 'send' then
    update wallets set balance = balance - p_amount, updated_at = now() where user_id = p_user_id;
  end if;
end;
$$ language plpgsql security definer;

-- Function to create or get wallet
create or replace function get_or_create_wallet(p_user_id uuid)
returns uuid as $$
declare
  wallet_id uuid;
begin
  select id into wallet_id from wallets where user_id = p_user_id;
  if wallet_id is null then
    insert into wallets (user_id) values (p_user_id) returning id into wallet_id;
  end if;
  return wallet_id;
end;
$$ language plpgsql security definer;