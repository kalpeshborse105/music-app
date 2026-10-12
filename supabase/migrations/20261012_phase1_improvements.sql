-- ====================================================================
-- Kalpkrut Beats - Phase 1 Database Migration
-- Owner: Kalpkrut Infotech
-- Purpose: Atomic user account deletion, secure RLS, and performance indices
-- ====================================================================

-- 1. Atomic User Account Deletion Function
-- Allows authenticated users to permanently delete their own account
-- and all associated data (favorites, playlists, history, settings, and profile)
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Remove user activity data
  DELETE FROM public.recently_played WHERE user_id = v_user_id;
  DELETE FROM public.favorites WHERE user_id = v_user_id;
  DELETE FROM public.playlist_tracks WHERE playlist_id IN (
    SELECT id FROM public.playlists WHERE user_id = v_user_id
  );
  DELETE FROM public.playlists WHERE user_id = v_user_id;
  DELETE FROM public.user_settings WHERE user_id = v_user_id;

  -- 2. Remove profile record
  DELETE FROM public.profiles WHERE id = v_user_id;

  -- 3. Remove from auth.users (cascades any remaining auth sessions/identities)
  DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

-- Secure execution permissions: strictly only authenticated users can run it for themselves
REVOKE EXECUTE ON FUNCTION public.delete_user_account() FROM public;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;

-- 2. Performance Indices for user lookups and regional feeds
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON public.favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_playlists_user_id ON public.playlists(user_id);
CREATE INDEX IF NOT EXISTS idx_recently_played_user_id ON public.recently_played(user_id);
