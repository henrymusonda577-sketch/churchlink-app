-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pg_net";
CREATE EXTENSION IF NOT EXISTS "vault";

-- Create reports table for post reports
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    reported_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies for reports
CREATE POLICY "Users can view reports they created" ON public.reports
    FOR SELECT USING (auth.uid() = reported_by);

CREATE POLICY "Users can insert reports" ON public.reports
    FOR INSERT WITH CHECK (auth.uid() = reported_by);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS reports_post_id_idx ON public.reports(post_id);
CREATE INDEX IF NOT EXISTS reports_reported_by_idx ON public.reports(reported_by);
CREATE INDEX IF NOT EXISTS reports_created_at_idx ON public.reports(created_at DESC);

-- Function to notify on report
CREATE OR REPLACE FUNCTION public.notify_report()
RETURNS TRIGGER AS $$
BEGIN
  -- Call the edge function via HTTP
  PERFORM
    net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/send-report-email',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (SELECT value FROM vault.secrets WHERE name = 'service_role_key')
      ),
      body := jsonb_build_object('record', row_to_json(NEW)::jsonb)
    );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to send email on report insert
CREATE TRIGGER notify_report_trigger
  AFTER INSERT ON public.reports
  FOR EACH ROW EXECUTE FUNCTION public.notify_report();