-- Adds a tier column to the existing fragrances table for AI classification.
-- Run this instead of creating a separate perfumes table.

alter table fragrances
  add column if not exists tier text;

create index if not exists fragrances_tier_null_idx
on fragrances (tier) where tier is null;
