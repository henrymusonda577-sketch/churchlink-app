-- Create tables for donation split payments
-- Run this in Supabase SQL editor

-- Table to store church payout accounts (subaccounts for split payments)
CREATE TABLE IF NOT EXISTS church_payout_accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    church_id UUID NOT NULL REFERENCES churches(id) ON DELETE CASCADE,
    account_type TEXT NOT NULL CHECK (account_type IN ('bank', 'mobile_money')),
    account_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    bank_name TEXT,
    bank_code TEXT,
    mobile_provider TEXT CHECK (mobile_provider IN ('airtel', 'mtn')),
    flutterwave_subaccount_id TEXT UNIQUE,
    flutterwave_account_id TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(church_id, account_type, account_number)
);

-- Table to record donation splits
CREATE TABLE IF NOT EXISTS donation_splits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    donation_id UUID NOT NULL REFERENCES donations(id) ON DELETE CASCADE,
    recipient_type TEXT NOT NULL CHECK (recipient_type IN ('platform', 'church')),
    recipient_id UUID, -- church_id for church splits
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'ZMW',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
    flutterwave_split_id TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add columns to donations table for split tracking
ALTER TABLE donations ADD COLUMN IF NOT EXISTS platform_fee DECIMAL(10,2) DEFAULT 0;
ALTER TABLE donations ADD COLUMN IF NOT EXISTS church_amount DECIMAL(10,2) DEFAULT 0;
ALTER TABLE donations ADD COLUMN IF NOT EXISTS split_processed BOOLEAN DEFAULT false;
ALTER TABLE donations ADD COLUMN IF NOT EXISTS transaction_id TEXT;

-- Enable RLS
ALTER TABLE church_payout_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE donation_splits ENABLE ROW LEVEL SECURITY;

-- RLS Policies for church_payout_accounts
CREATE POLICY "Pastors can manage their church payout accounts" ON church_payout_accounts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM churches
            WHERE churches.id = church_payout_accounts.church_id
            AND churches.pastor_id = auth.uid()
        )
    );

CREATE POLICY "Church members can view payout accounts" ON church_payout_accounts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.church_id = church_payout_accounts.church_id
        )
    );

-- RLS Policies for donation_splits
CREATE POLICY "Users can view splits for their donations" ON donation_splits
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM donations
            WHERE donations.id = donation_splits.donation_id
            AND donations.user_id = auth.uid()
        )
    );

CREATE POLICY "Pastors can view splits for their church donations" ON donation_splits
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM donations d
            JOIN churches c ON d.church_id = c.id
            WHERE d.id = donation_splits.donation_id
            AND c.pastor_id = auth.uid()
        )
    );

CREATE POLICY "System can create donation splits" ON donation_splits
    FOR INSERT WITH CHECK (true);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_church_payout_accounts_church_id ON church_payout_accounts(church_id);
CREATE INDEX IF NOT EXISTS idx_church_payout_accounts_active ON church_payout_accounts(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_donation_splits_donation_id ON donation_splits(donation_id);
CREATE INDEX IF NOT EXISTS idx_donation_splits_status ON donation_splits(status);
CREATE INDEX IF NOT EXISTS idx_donations_split_processed ON donations(split_processed);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for church_payout_accounts
CREATE TRIGGER update_church_payout_accounts_updated_at
    BEFORE UPDATE ON church_payout_accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();