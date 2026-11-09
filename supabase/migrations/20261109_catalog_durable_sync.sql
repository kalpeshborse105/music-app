-- ====================================================================
-- Kalpkrut Beats - Phase D: Durable Track Storage & Sync Architecture
-- Migration: 20261109_catalog_durable_sync.sql
-- Owner: Kalpkrut Infotech
-- Purpose:
--   1. Add columns to catalog_sections: content_hash, content_version, track_count, custom_tracks, excluded_track_ids, display_mode
--   2. Create catalog_section_tracks table for durable, normalized track storage
--   3. Create catalog_sync_jobs table for durable background refresh queue & lease recovery
--   4. Enable RLS and define security policies
--   5. Provide atomic snapshot replacement function replace_catalog_section_tracks()
-- ====================================================================

-- 1. Extend catalog_sections metadata columns
ALTER TABLE public.catalog_sections
    ADD COLUMN IF NOT EXISTS content_hash TEXT,
    ADD COLUMN IF NOT EXISTS content_version BIGINT DEFAULT 1,
    ADD COLUMN IF NOT EXISTS track_count INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS custom_tracks JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS excluded_track_ids JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS display_mode TEXT DEFAULT 'playlists';

-- 2. Durable Normalized Track Storage
CREATE TABLE IF NOT EXISTS public.catalog_section_tracks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id UUID NOT NULL REFERENCES public.catalog_sections(id) ON DELETE CASCADE,
    section_key TEXT NOT NULL,
    track_id TEXT NOT NULL,
    position INT NOT NULL DEFAULT 1,
    title TEXT NOT NULL,
    artist TEXT,
    album TEXT,
    artwork_url TEXT,
    duration_ms INT DEFAULT 0,
    language TEXT,
    year TEXT,
    source_metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_catalog_section_track UNIQUE (section_id, track_id)
);

-- Fast lookup by section and display order
CREATE INDEX IF NOT EXISTS idx_section_tracks_lookup
    ON public.catalog_section_tracks(section_id, position ASC);

CREATE INDEX IF NOT EXISTS idx_section_tracks_by_key
    ON public.catalog_section_tracks(section_key, position ASC);

CREATE INDEX IF NOT EXISTS idx_section_tracks_track_id
    ON public.catalog_section_tracks(track_id);

-- 3. Durable Background Sync Job Queue (Handles Render Free spin-downs & lease timeouts)
CREATE TABLE IF NOT EXISTS public.catalog_sync_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id TEXT,
    section_id UUID REFERENCES public.catalog_sections(id) ON DELETE CASCADE,
    section_key TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'completed', 'failed')),
    worker_id TEXT,
    lease_expires_at TIMESTAMPTZ,
    attempt_count INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    last_error TEXT,
    tracks_found INT DEFAULT 0,
    changed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_jobs_status_lease
    ON public.catalog_sync_jobs(status, lease_expires_at);

CREATE INDEX IF NOT EXISTS idx_sync_jobs_batch
    ON public.catalog_sync_jobs(batch_id);

CREATE INDEX IF NOT EXISTS idx_sync_jobs_section_key
    ON public.catalog_sync_jobs(section_key);

-- 4. Row Level Security (RLS) Configuration

-- Enable RLS on newly created tables
ALTER TABLE public.catalog_section_tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_sync_jobs ENABLE ROW LEVEL SECURITY;

-- catalog_section_tracks Policies:
-- Public can read tracks for sections that are enabled and active
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'catalog_section_tracks'
        AND policyname = 'Public can view active section tracks'
    ) THEN
        CREATE POLICY "Public can view active section tracks"
            ON public.catalog_section_tracks FOR SELECT
            USING (
                EXISTS (
                    SELECT 1 FROM public.catalog_sections s
                    WHERE s.id = catalog_section_tracks.section_id
                      AND s.is_enabled = TRUE
                      AND (s.campaign_start IS NULL OR s.campaign_start <= NOW())
                      AND (s.campaign_end IS NULL OR s.campaign_end >= NOW())
                )
            );
    END IF;
END $$;

-- Admins and Service-role have full access to catalog_section_tracks
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'catalog_section_tracks'
        AND policyname = 'Admins can manage section tracks'
    ) THEN
        CREATE POLICY "Admins can manage section tracks"
            ON public.catalog_section_tracks FOR ALL
            USING (
                EXISTS (
                    SELECT 1 FROM public.profiles
                    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.profiles
                    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
                )
            );
    END IF;
END $$;

-- catalog_sync_jobs Policies:
-- Only admins and service role can view and manage sync jobs
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'catalog_sync_jobs'
        AND policyname = 'Admins can manage catalog sync jobs'
    ) THEN
        CREATE POLICY "Admins can manage catalog sync jobs"
            ON public.catalog_sync_jobs FOR ALL
            USING (
                EXISTS (
                    SELECT 1 FROM public.profiles
                    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.profiles
                    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
                )
            );
    END IF;
END $$;

-- 5. Atomic Snapshot Replacement Function
-- Allows atomic deletion of stale tracks, insertion of current tracks,
-- bumping of content_version, and updating of content_hash and last_refresh.
CREATE OR REPLACE FUNCTION public.replace_catalog_section_tracks(
    p_section_id UUID,
    p_section_key TEXT,
    p_content_hash TEXT,
    p_tracks JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_track JSONB;
    v_pos INT := 1;
    v_inserted INT := 0;
    v_new_version BIGINT;
BEGIN
    -- 1. Wipe existing tracks for this section
    DELETE FROM public.catalog_section_tracks
    WHERE section_id = p_section_id;

    -- 2. Insert new track snapshot
    FOR v_track IN SELECT * FROM jsonb_array_elements(p_tracks)
    LOOP
        INSERT INTO public.catalog_section_tracks (
            section_id,
            section_key,
            track_id,
            position,
            title,
            artist,
            album,
            artwork_url,
            duration_ms,
            language,
            year,
            source_metadata,
            updated_at
        ) VALUES (
            p_section_id,
            p_section_key,
            COALESCE(v_track->>'id', v_track->>'token', v_pos::TEXT),
            v_pos,
            COALESCE(v_track->>'title', 'Untitled'),
            v_track->>'artist',
            v_track->>'album',
            COALESCE(v_track->>'artwork_url', v_track->>'thumbnail', v_track->>'image'),
            COALESCE((v_track->>'duration_ms')::INT, ((v_track->>'duration')::INT * 1000), 0),
            COALESCE(v_track->>'language', 'all'),
            v_track->>'year',
            v_track,
            NOW()
        )
        ON CONFLICT (section_id, track_id) DO UPDATE SET
            position = EXCLUDED.position,
            title = EXCLUDED.title,
            artist = EXCLUDED.artist,
            album = EXCLUDED.album,
            artwork_url = EXCLUDED.artwork_url,
            duration_ms = EXCLUDED.duration_ms,
            source_metadata = EXCLUDED.source_metadata,
            updated_at = NOW();

        v_pos := v_pos + 1;
        v_inserted := v_inserted + 1;
    END LOOP;

    -- 3. Bump content_version, update content_hash, track_count, and last_refresh on catalog_sections
    UPDATE public.catalog_sections
    SET
        content_hash = p_content_hash,
        content_version = COALESCE(content_version, 0) + 1,
        track_count = v_inserted,
        last_refresh = NOW(),
        updated_at = NOW(),
        provider_status = 'ok',
        last_error = NULL
    WHERE id = p_section_id
    RETURNING content_version INTO v_new_version;

    RETURN jsonb_build_object(
        'success', TRUE,
        'section_id', p_section_id,
        'section_key', p_section_key,
        'tracks_saved', v_inserted,
        'content_hash', p_content_hash,
        'content_version', v_new_version
    );
END;
$$;

