-- ====================================================================
-- Kalpkrut Beats Music Streaming Platform - Database Schema
-- Owner: Kalpkrut Infotech
-- Supabase PostgreSQL with Strict Row Level Security (RLS)
-- ====================================================================

-- 1. Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ====================================================================
-- 2. PUBLIC CATALOG TABLES (Controlled / Read-accessible by all users)
-- ====================================================================

-- Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    subtitle TEXT,
    icon_name TEXT,
    gradient_colors TEXT[] DEFAULT ARRAY['#8B5CF6', '#3B82F6'],
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Artists Table
CREATE TABLE IF NOT EXISTS public.artists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider TEXT NOT NULL DEFAULT 'jamendo',
    provider_artist_id TEXT,
    name TEXT NOT NULL,
    bio TEXT,
    image_url TEXT,
    website_url TEXT,
    monthly_listeners BIGINT DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_artist_provider UNIQUE (provider, provider_artist_id)
);

-- Albums Table
CREATE TABLE IF NOT EXISTS public.albums (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider TEXT NOT NULL DEFAULT 'jamendo',
    provider_album_id TEXT,
    title TEXT NOT NULL,
    artist_id UUID REFERENCES public.artists(id) ON DELETE SET NULL,
    artist_name TEXT NOT NULL,
    artwork_url TEXT,
    release_date DATE,
    genre TEXT,
    track_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_album_provider UNIQUE (provider, provider_album_id)
);

-- Tracks Table (Provider-independent normalized legal track catalog)
CREATE TABLE IF NOT EXISTS public.tracks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider TEXT NOT NULL DEFAULT 'jamendo',
    provider_track_id TEXT NOT NULL,
    title TEXT NOT NULL,
    artist_id UUID REFERENCES public.artists(id) ON DELETE SET NULL,
    artist_name TEXT NOT NULL,
    album_id UUID REFERENCES public.albums(id) ON DELETE SET NULL,
    album_title TEXT,
    artwork_url TEXT,
    duration_ms INT NOT NULL DEFAULT 0,
    genre TEXT,
    license_type TEXT NOT NULL DEFAULT 'Creative Commons',
    license_url TEXT,
    artist_url TEXT,
    stream_url TEXT,
    waveform_data JSONB,
    is_playable BOOLEAN DEFAULT TRUE,
    play_count BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_track_provider UNIQUE (provider, provider_track_id)
);

-- ====================================================================
-- 3. USER DATA & PRIVATE TABLES (Protected by Strict RLS)
-- ====================================================================

-- User Profiles (Linked directly to auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE,
    display_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    preferred_language TEXT DEFAULT 'en',
    is_pro BOOLEAN DEFAULT FALSE,
    role TEXT DEFAULT 'user' CHECK (role IN ('user', 'curator', 'admin')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Settings
CREATE TABLE IF NOT EXISTS public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    theme_mode TEXT DEFAULT 'dark' CHECK (theme_mode IN ('system', 'light', 'dark')),
    audio_quality TEXT DEFAULT 'high' CHECK (audio_quality IN ('auto', 'data_saver', 'standard', 'high', 'lossless')),
    download_over_wifi_only BOOLEAN DEFAULT TRUE,
    normalize_volume BOOLEAN DEFAULT TRUE,
    crossfade_seconds INT DEFAULT 0 CHECK (crossfade_seconds >= 0 AND crossfade_seconds <= 12),
    enable_haptics BOOLEAN DEFAULT TRUE,
    push_notifications BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Connected Devices
CREATE TABLE IF NOT EXISTS public.user_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT NOT NULL,
    platform TEXT NOT NULL,
    app_version TEXT,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_device UNIQUE (user_id, device_id)
);

-- User Playlists
CREATE TABLE IF NOT EXISTS public.playlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    artwork_url TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    track_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Playlist Tracks (Ordered join table)
CREATE TABLE IF NOT EXISTS public.playlist_tracks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    playlist_id UUID NOT NULL REFERENCES public.playlists(id) ON DELETE CASCADE,
    track_id UUID REFERENCES public.tracks(id) ON DELETE CASCADE,
    custom_track_data JSONB,
    position INT NOT NULL DEFAULT 0,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_playlist_track_pos UNIQUE (playlist_id, position)
);

-- User Favorites / Liked Songs
CREATE TABLE IF NOT EXISTS public.favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    track_id UUID REFERENCES public.tracks(id) ON DELETE CASCADE,
    local_track_id TEXT,
    custom_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_track_fav UNIQUE (user_id, track_id)
);

-- Recently Played (Deduplicated session history)
CREATE TABLE IF NOT EXISTS public.recently_played (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    track_id UUID REFERENCES public.tracks(id) ON DELETE CASCADE,
    custom_metadata JSONB,
    played_at TIMESTAMPTZ DEFAULT NOW(),
    duration_played_ms INT DEFAULT 0
);

-- Playback Queue (Cross-device synced queue)
CREATE TABLE IF NOT EXISTS public.playback_queue (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_track_id UUID REFERENCES public.tracks(id) ON DELETE SET NULL,
    current_position_ms INT DEFAULT 0,
    queue_items JSONB DEFAULT '[]'::jsonb,
    is_shuffled BOOLEAN DEFAULT FALSE,
    repeat_mode TEXT DEFAULT 'off' CHECK (repeat_mode IN ('off', 'all', 'one')),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Reports & Feedback
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    track_id UUID REFERENCES public.tracks(id) ON DELETE SET NULL,
    report_type TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'investigating', 'resolved', 'dismissed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ====================================================================
-- 4. INDEXES FOR HIGH-PERFORMANCE QUERYING
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_tracks_provider_id ON public.tracks (provider, provider_track_id);
CREATE INDEX IF NOT EXISTS idx_tracks_genre ON public.tracks (genre);
CREATE INDEX IF NOT EXISTS idx_tracks_artist_id ON public.tracks (artist_id);
CREATE INDEX IF NOT EXISTS idx_tracks_album_id ON public.tracks (album_id);

CREATE INDEX IF NOT EXISTS idx_playlists_user ON public.playlists (user_id);
CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist ON public.playlist_tracks (playlist_id, position);
CREATE INDEX IF NOT EXISTS idx_favorites_user ON public.favorites (user_id);
CREATE INDEX IF NOT EXISTS idx_recently_played_user_date ON public.recently_played (user_id, played_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_devices_user ON public.user_devices (user_id);

-- ====================================================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

-- Enable RLS on all tables
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.artists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playlist_tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recently_played ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playback_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Public Catalog Read Access (Categories, Artists, Albums, Tracks)
CREATE POLICY "Public categories are readable by everyone" 
    ON public.categories FOR SELECT USING (true);

CREATE POLICY "Artists are readable by everyone" 
    ON public.artists FOR SELECT USING (true);

CREATE POLICY "Albums are readable by everyone" 
    ON public.albums FOR SELECT USING (true);

CREATE POLICY "Playable tracks are readable by everyone" 
    ON public.tracks FOR SELECT USING (is_playable = true);

-- Profiles Policies
CREATE POLICY "Profiles are viewable by everyone" 
    ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" 
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
    ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- User Settings Policies
CREATE POLICY "Users can manage their own settings" 
    ON public.user_settings FOR ALL USING (auth.uid() = user_id);

-- User Devices Policies
CREATE POLICY "Users can manage their own devices" 
    ON public.user_devices FOR ALL USING (auth.uid() = user_id);

-- Playlists Policies
CREATE POLICY "Public playlists are viewable by everyone" 
    ON public.playlists FOR SELECT USING (is_public = true OR auth.uid() = user_id);

CREATE POLICY "Users can create playlists" 
    ON public.playlists FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own playlists" 
    ON public.playlists FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own playlists" 
    ON public.playlists FOR DELETE USING (auth.uid() = user_id);

-- Playlist Tracks Policies
CREATE POLICY "Users can view playlist tracks for accessible playlists" 
    ON public.playlist_tracks FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.playlists p 
            WHERE p.id = playlist_tracks.playlist_id 
            AND (p.is_public = true OR p.user_id = auth.uid())
        )
    );

CREATE POLICY "Users can manage playlist tracks in their own playlists" 
    ON public.playlist_tracks FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.playlists p 
            WHERE p.id = playlist_tracks.playlist_id 
            AND p.user_id = auth.uid()
        )
    );

-- Favorites Policies
CREATE POLICY "Users can manage their own favorites" 
    ON public.favorites FOR ALL USING (auth.uid() = user_id);

-- Recently Played Policies
CREATE POLICY "Users can manage their recently played history" 
    ON public.recently_played FOR ALL USING (auth.uid() = user_id);

-- Playback Queue Policies
CREATE POLICY "Users can manage their playback queue" 
    ON public.playback_queue FOR ALL USING (auth.uid() = user_id);

-- Reports Policies
CREATE POLICY "Users can insert reports" 
    ON public.reports FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NULL);

CREATE POLICY "Users can view their own reports" 
    ON public.reports FOR SELECT USING (auth.uid() = user_id);

-- ====================================================================
-- 6. AUTOMATIC PROFILE & SETTINGS TRIGGER ON AUTH SIGNUP
-- ====================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, display_name, avatar_url)
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
        new.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.user_settings (user_id)
    VALUES (new.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ====================================================================
-- 7. ADVERTISEMENTS & ANNOUNCEMENTS TABLE (ADMIN MANAGED)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.advertisements (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    title TEXT NOT NULL,
    subtitle TEXT,
    image_url TEXT NOT NULL,
    target_url TEXT,
    is_active BOOLEAN DEFAULT true,
    close_button_type TEXT DEFAULT 'icon', -- 'icon', 'text_and_cross', 'text_only'
    display_order INT DEFAULT 0,
    placement TEXT DEFAULT 'popup', -- popup | home_pre_radio | home_post_recent | catalog_mid | library_mid | playlist_mid
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.advertisements ENABLE ROW LEVEL SECURITY;

-- Everyone (authenticated & anon) can read active ads
CREATE POLICY "Public can view active advertisements"
    ON public.advertisements FOR SELECT
    USING (is_active = true);

-- Admins can perform all operations on advertisements
CREATE POLICY "Admins have full access to advertisements"
    ON public.advertisements FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

-- ====================================================================
-- 8. CATALOGUE ORCHESTRATION & DYNAMIC SECTIONS (ADMIN CMS)
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

CREATE INDEX IF NOT EXISTS idx_catalog_sections_pos ON public.catalog_sections (position ASC);
CREATE INDEX IF NOT EXISTS idx_catalog_sections_enabled ON public.catalog_sections (is_enabled, position ASC);
CREATE INDEX IF NOT EXISTS idx_catalog_sections_group ON public.catalog_sections (display_group);
CREATE INDEX IF NOT EXISTS idx_catalog_sections_key ON public.catalog_sections (key);

ALTER TABLE public.catalog_sections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view active catalog sections"
    ON public.catalog_sections FOR SELECT
    USING (
        is_enabled = true
        AND (campaign_start IS NULL OR campaign_start <= NOW())
        AND (campaign_end IS NULL OR campaign_end >= NOW())
    );

CREATE POLICY "Admins can view all catalog sections"
    ON public.catalog_sections FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

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

