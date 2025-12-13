-- Drop existing table if it exists with wrong structure
DROP TABLE IF EXISTS email_verification_codes;

create table email_verification_codes (
  id uuid default gen_random_uuid() primary key,
  email text not null,
  code text not null,
  expires_at timestamp with time zone not null,
  verified boolean default false,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create index email_verification_codes_email_idx on email_verification_codes(email);

alter table email_verification_codes enable row level security;

create policy "Service role only" on email_verification_codes
  for all using (auth.role() = 'service_role');

-- Function to clean up expired codes
create or replace function cleanup_expired_codes()
returns trigger as $$
begin
  delete from email_verification_codes
  where expires_at < now();
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to cleanup on insert
create trigger cleanup_expired_verification_codes
  after insert on email_verification_codes
  execute procedure cleanup_expired_codes();