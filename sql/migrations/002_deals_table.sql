CREATE TABLE IF NOT EXISTS deals (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_name  text        NOT NULL,
  description text        NOT NULL,
  color_hex   text        NOT NULL DEFAULT '#3D2314',
  url         text,
  is_active   boolean     NOT NULL DEFAULT true,
  expires_at  timestamptz,
  sort_order  integer     NOT NULL DEFAULT 0,
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS deals_active_sort_idx
  ON deals (is_active, sort_order);

-- Deals are public read-only; only service-role writes are allowed.
ALTER TABLE deals ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'deals'
      AND policyname = 'Deals are publicly readable'
  ) THEN
    CREATE POLICY "Deals are publicly readable"
    ON deals FOR SELECT USING (true);
  END IF;
END $$;

-- Seed data matching the previous hardcoded values.
INSERT INTO deals (store_name, description, color_hex, sort_order)
VALUES
  ('Golden Scent', '20% off Creed', '#1a6b3a', 0),
  ('Amazon.sa',    'Deal of the Day',    '#FF9900', 1),
  ('Riyadh Expo',  'Up to 50% off',      '#3D2314', 2)
ON CONFLICT DO NOTHING;
