-- Inline ad placement slots controlled from Admin → Ads
ALTER TABLE public.advertisements
  ADD COLUMN IF NOT EXISTS placement TEXT DEFAULT 'popup';

COMMENT ON COLUMN public.advertisements.placement IS
  'popup | home_pre_radio | home_post_recent | catalog_mid | library_mid | playlist_mid';

CREATE INDEX IF NOT EXISTS idx_advertisements_placement_active
  ON public.advertisements (placement, is_active, display_order);
