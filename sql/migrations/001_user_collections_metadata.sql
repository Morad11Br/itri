-- Adds metadata columns captured by the manual-entry form in AddScreen.
-- Run once against your Supabase project via the SQL editor or CLI.

ALTER TABLE user_collections
  ADD COLUMN IF NOT EXISTS concentration       text,
  ADD COLUMN IF NOT EXISTS acquisition_source  text,
  ADD COLUMN IF NOT EXISTS price_paid          numeric,
  ADD COLUMN IF NOT EXISTS personal_notes      text,
  ADD COLUMN IF NOT EXISTS custom_accords      text[];

-- Allow authenticated users to write custom stub rows to fragrances.
-- Manual-entry perfumes are inserted with source_id prefix 'custom_'.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'fragrances'
      AND policyname = 'Authenticated users can insert custom perfumes'
  ) THEN
    ALTER TABLE fragrances ENABLE ROW LEVEL SECURITY;

    CREATE POLICY "Fragrances are publicly readable"
    ON fragrances FOR SELECT USING (true);

    CREATE POLICY "Authenticated users can insert custom perfumes"
    ON fragrances FOR INSERT
    WITH CHECK (auth.role() = 'authenticated' AND source_id LIKE 'custom_%');
  END IF;
END $$;
