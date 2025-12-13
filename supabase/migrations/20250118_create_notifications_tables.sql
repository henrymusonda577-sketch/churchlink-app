-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'like', 'comment', 'follow', 'event', 'custom', 'push'
    from_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    title TEXT,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create notification_subscriptions table
CREATE TABLE IF NOT EXISTS public.notification_subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    church_id UUID REFERENCES public.churches(id) ON DELETE CASCADE,
    subscribed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(user_id, church_id)
);

-- Create notification_preferences table
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    prayers BOOLEAN DEFAULT TRUE,
    events BOOLEAN DEFAULT TRUE,
    messages BOOLEAN DEFAULT TRUE,
    live_streams BOOLEAN DEFAULT TRUE,
    church_updates BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create scheduled_notifications table
CREATE TABLE IF NOT EXISTS public.scheduled_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    from_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    scheduled_for TIMESTAMP WITH TIME ZONE NOT NULL,
    is_sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheduled_notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notifications
CREATE POLICY "Users can view their own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert notifications for others" ON public.notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own notifications" ON public.notifications
    FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for notification_subscriptions
CREATE POLICY "Users can view their own subscriptions" ON public.notification_subscriptions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own subscriptions" ON public.notification_subscriptions
    FOR ALL USING (auth.uid() = user_id);

-- RLS Policies for notification_preferences
CREATE POLICY "Users can view their own preferences" ON public.notification_preferences
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own preferences" ON public.notification_preferences
    FOR ALL USING (auth.uid() = user_id);

-- RLS Policies for scheduled_notifications
CREATE POLICY "Users can view their own scheduled notifications" ON public.scheduled_notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert scheduled notifications" ON public.scheduled_notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their own scheduled notifications" ON public.scheduled_notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_is_read_idx ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS notifications_created_at_idx ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS notification_subscriptions_user_id_idx ON public.notification_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS notification_subscriptions_church_id_idx ON public.notification_subscriptions(church_id);
CREATE INDEX IF NOT EXISTS notification_preferences_user_id_idx ON public.notification_preferences(user_id);
CREATE INDEX IF NOT EXISTS scheduled_notifications_user_id_idx ON public.scheduled_notifications(user_id);
CREATE INDEX IF NOT EXISTS scheduled_notifications_scheduled_for_idx ON public.scheduled_notifications(scheduled_for);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER handle_notifications_updated_at
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW EXECUTE FUNCTION public.handle_notifications_updated_at();

CREATE TRIGGER handle_notification_preferences_updated_at
    BEFORE UPDATE ON public.notification_preferences
    FOR EACH ROW EXECUTE FUNCTION public.handle_notifications_updated_at();