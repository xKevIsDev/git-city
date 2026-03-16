-- Add fiscal/billing data columns to purchases
-- Captured from Stripe checkout when customer fills billing address + tax ID
alter table purchases
  add column if not exists buyer_name        text,
  add column if not exists buyer_email       text,
  add column if not exists buyer_tax_id      text,
  add column if not exists buyer_tax_id_type text,
  add column if not exists buyer_country     text,
  add column if not exists buyer_address     jsonb;