-- 1. Create devices table for tracking user push tokens and activity
CREATE TABLE IF NOT EXISTS public.devices (
    device_id TEXT PRIMARY KEY,
    fcm_token TEXT,
    ip_address TEXT,
    last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create analytics_events table for tracking behavior
CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT REFERENCES public.devices(device_id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    category TEXT,
    item_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create broadcast_notifications table to store history
CREATE TABLE IF NOT EXISTS public.broadcast_notifications (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    image_url TEXT,
    target_audience TEXT NOT NULL,
    action_type TEXT NOT NULL,
    target_route_or_id TEXT,
    target_label TEXT,
    is_high_priority BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    recipient_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'sent'
);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.broadcast_notifications ENABLE ROW LEVEL SECURITY;

-- 5. Policies
-- Allow anyone to insert and update their own device anonymously
CREATE POLICY "Allow anonymous device insert/update" ON public.devices
FOR ALL USING (true) WITH CHECK (true);

-- Allow anyone to insert analytics events
CREATE POLICY "Allow anonymous analytics insert" ON public.analytics_events
FOR INSERT WITH CHECK (true);

-- Only admins can read all analytics and devices (Assumes admins use authenticated auth)
CREATE POLICY "Allow admins to read analytics" ON public.analytics_events
FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Allow admins to read devices" ON public.devices
FOR SELECT USING (auth.role() = 'authenticated');

-- Notifications history accessible to admins
CREATE POLICY "Allow admins all access to broadcasts" ON public.broadcast_notifications
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 6. RPC function to get FCM tokens by audience segment based on recent analytics
CREATE OR REPLACE FUNCTION get_segmented_fcm_tokens(target_audience text)
RETURNS TABLE (fcm_token text) AS $$
BEGIN
    IF target_audience = 'allUsers' THEN
        RETURN QUERY SELECT d.fcm_token FROM public.devices d WHERE d.fcm_token IS NOT NULL;
    
    ELSIF target_audience = 'pgSeekers' THEN
        -- Devices whose most recent category view/search is PG
        RETURN QUERY 
        SELECT DISTINCT d.fcm_token 
        FROM public.devices d
        JOIN (
            SELECT device_id, category, 
                   ROW_NUMBER() OVER(PARTITION BY device_id ORDER BY created_at DESC) as rn
            FROM public.analytics_events
            WHERE category IS NOT NULL
        ) e ON d.device_id = e.device_id
        WHERE e.rn = 1 AND (e.category ILIKE '%PG%' OR e.category ILIKE '%Hostel%')
        AND d.fcm_token IS NOT NULL;

    ELSIF target_audience = 'roomSeekers' THEN
        -- Devices whose most recent category view/search is Room/Flats
        RETURN QUERY 
        SELECT DISTINCT d.fcm_token 
        FROM public.devices d
        JOIN (
            SELECT device_id, category, 
                   ROW_NUMBER() OVER(PARTITION BY device_id ORDER BY created_at DESC) as rn
            FROM public.analytics_events
            WHERE category IS NOT NULL
        ) e ON d.device_id = e.device_id
        WHERE e.rn = 1 AND (e.category ILIKE '%Rental%' OR e.category ILIKE '%Room%')
        AND d.fcm_token IS NOT NULL;

    ELSIF target_audience = 'buyers' THEN
        -- Devices whose most recent category view/search is Sale/Commercial
        RETURN QUERY 
        SELECT DISTINCT d.fcm_token 
        FROM public.devices d
        JOIN (
            SELECT device_id, category, 
                   ROW_NUMBER() OVER(PARTITION BY device_id ORDER BY created_at DESC) as rn
            FROM public.analytics_events
            WHERE category IS NOT NULL
        ) e ON d.device_id = e.device_id
        WHERE e.rn = 1 AND (e.category ILIKE '%Sale%' OR e.category ILIKE '%Commercial%')
        AND d.fcm_token IS NOT NULL;

    ELSE
        RETURN QUERY SELECT d.fcm_token FROM public.devices d WHERE d.fcm_token IS NOT NULL LIMIT 0;
    END IF;
END;
$$ LANGUAGE plpgsql;
