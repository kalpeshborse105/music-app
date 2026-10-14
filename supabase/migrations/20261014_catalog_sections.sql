-- ====================================================================
-- Kalpkrut Beats - Catalogue Orchestration & Admin CMS Migration
-- Owner: Kalpkrut Infotech
-- Purpose: Persistent catalog_sections table with strict RLS and campaign scheduling
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.catalog_sections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key TEXT UNIQUE NOT NULL,
    source_url TEXT NOT NULL,
    source_type TEXT NOT NULL CHECK (source_type IN ('playlist', 'album', 'artist', 'new_releases', 'charts', 'top_artists')),
    provider TEXT NOT NULL DEFAULT 'custom_api',
    source_id TEXT NOT NULL DEFAULT '',
    slug TEXT,
    display_title TEXT NOT NULL,
    subtitle TEXT,
    display_group TEXT NOT NULL DEFAULT 'Featured',
    language TEXT NOT NULL DEFAULT 'all',
    position INT NOT NULL DEFAULT 1,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    custom_artwork_url TEXT,
    is_banner BOOLEAN NOT NULL DEFAULT FALSE,
    campaign_start TIMESTAMPTZ,
    campaign_end TIMESTAMPTZ,
    provider_status TEXT DEFAULT 'ok',
    last_refresh TIMESTAMPTZ DEFAULT NOW(),
    last_error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Indices for high-performance retrieval and ordering
CREATE INDEX IF NOT EXISTS idx_catalog_sections_pos ON public.catalog_sections (position ASC);
CREATE INDEX IF NOT EXISTS idx_catalog_sections_enabled ON public.catalog_sections (is_enabled, position ASC);
CREATE INDEX IF NOT EXISTS idx_catalog_sections_group ON public.catalog_sections (display_group);
CREATE INDEX IF NOT EXISTS idx_catalog_sections_key ON public.catalog_sections (key);

-- Enable RLS
ALTER TABLE public.catalog_sections ENABLE ROW LEVEL SECURITY;

-- 1. Public Read Policy:
-- Unauthenticated & regular users can view only active/published sections within their campaign window
CREATE POLICY "Public can view active catalog sections"
    ON public.catalog_sections FOR SELECT
    USING (
        is_enabled = true
        AND (campaign_start IS NULL OR campaign_start <= NOW())
        AND (campaign_end IS NULL OR campaign_end >= NOW())
    );

-- 2. Admin Read Policy:
-- Administrators can view ALL sections (including disabled, draft, expired, or future campaigns)
CREATE POLICY "Admins can view all catalog sections"
    ON public.catalog_sections FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

-- 3. Admin Mutation Policies:
-- Only authenticated administrators can create, update, reorder, or delete sections
CREATE POLICY "Admins can insert catalog sections"
    ON public.catalog_sections FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

CREATE POLICY "Admins can update catalog sections"
    ON public.catalog_sections FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

CREATE POLICY "Admins can delete catalog sections"
    ON public.catalog_sections FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );
