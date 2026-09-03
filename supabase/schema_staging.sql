-- ====================================================================
-- SAFE ISOLATED STAGING TABLE FOR ADMIN AI SCRAPER PIPELINE
-- (This table runs alongside your live DB without touching 'properties')
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.admin_staging_properties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id TEXT NOT NULL,
    stage INTEGER NOT NULL DEFAULT 1, -- 1: Discovered, 2: Scraped, 3: In Review, 4: Approved, 5: Published
    title TEXT NOT NULL,
    location_str TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    raw_data JSONB DEFAULT '{}'::jsonb, -- Holds scraped phone, rent, facilities, raw photo URLs
    edited_data JSONB DEFAULT '{}'::jsonb, -- Holds full PropertyModel fields edited by admin in Stage 3
    selected_photo_urls TEXT[] DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'staged',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index for fast batch lookup
CREATE INDEX IF NOT EXISTS idx_admin_staging_batch_id ON public.admin_staging_properties(batch_id);
CREATE INDEX IF NOT EXISTS idx_admin_staging_stage ON public.admin_staging_properties(stage);

-- RLS Security Policies (Admin access)
ALTER TABLE public.admin_staging_properties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated admin full access to staging properties" 
ON public.admin_staging_properties
FOR ALL 
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow anon select staging properties for admin tools"
ON public.admin_staging_properties
FOR SELECT
TO anon
USING (true);
