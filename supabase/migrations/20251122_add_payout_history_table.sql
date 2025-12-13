-- Add payout history table for church withdrawals
-- Run this in Supabase SQL editor

-- Table to track church payouts/withdrawals
CREATE TABLE IF NOT EXISTS payout_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    church_id UUID NOT NULL REFERENCES churches(id) ON DELETE CASCADE,
    payout_account_id UUID NOT NULL REFERENCES church_payout_accounts(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'ZMW',
    flutterwave_transfer_id TEXT UNIQUE,
    reference TEXT UNIQUE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'successful', 'failed')),
    narration TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE payout_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for payout_history
CREATE POLICY "Pastors can view their church payout history" ON payout_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM churches
            WHERE churches.id = payout_history.church_id
            AND churches.pastor_id = auth.uid()
        )
    );

CREATE POLICY "System can create payout history" ON payout_history
    FOR INSERT WITH CHECK (true);

CREATE POLICY "System can update payout status" ON payout_history
    FOR UPDATE USING (true);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_payout_history_church_id ON payout_history(church_id);
CREATE INDEX IF NOT EXISTS idx_payout_history_status ON payout_history(status);
CREATE INDEX IF NOT EXISTS idx_payout_history_created_at ON payout_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payout_history_flutterwave_transfer_id ON payout_history(flutterwave_transfer_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_payout_history_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for payout_history
CREATE TRIGGER update_payout_history_updated_at
    BEFORE UPDATE ON payout_history
    FOR EACH ROW EXECUTE FUNCTION update_payout_history_updated_at();