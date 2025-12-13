-- Hybrid donation payout system migration
-- Add support for manual payouts alongside automated ones

-- Add method column to payout_history
ALTER TABLE payout_history ADD COLUMN IF NOT EXISTS method TEXT DEFAULT 'automatic' CHECK (method IN ('automatic', 'manual'));

-- Add admin_id for manual payouts (who approved/completed it)
ALTER TABLE payout_history ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES auth.users(id);

-- Add method index
CREATE INDEX IF NOT EXISTS idx_payout_history_method ON payout_history(method);

-- Update RLS policies to allow admins to update manual payouts
-- (Assuming there's an admin role, but for now allow system updates)

-- For manual payouts, we don't need flutterwave_transfer_id, so make it nullable
-- Already is nullable

-- Add a view for church balances
CREATE OR REPLACE VIEW church_balances AS
SELECT
    c.id as church_id,
    c.church_name,
    COALESCE(SUM(ds.amount), 0) as total_church_amount,
    COALESCE(SUM(CASE WHEN ph.status = 'successful' THEN ph.amount ELSE 0 END), 0) as total_paid_out,
    COALESCE(SUM(ds.amount), 0) - COALESCE(SUM(CASE WHEN ph.status = 'successful' THEN ph.amount ELSE 0 END), 0) as available_balance,
    MAX(ph.created_at) as last_payout_date
FROM churches c
LEFT JOIN donation_splits ds ON ds.recipient_id = c.id AND ds.recipient_type = 'church'
LEFT JOIN payout_history ph ON ph.church_id = c.id
GROUP BY c.id, c.church_name;

-- Grant access to the view
GRANT SELECT ON church_balances TO authenticated;