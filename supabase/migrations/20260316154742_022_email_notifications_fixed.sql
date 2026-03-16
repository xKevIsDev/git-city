-- 022: Notification system (channel-agnostic: email, push, in_app)
-- Architecture based on Knock/Novu patterns. Email now, push ready.

-- ── developers table: email + activity tracking ──
ALTER TABLE developers
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS email_updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'UTC',
  ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_developers_email ON developers (email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_developers_last_active_at ON developers (last_active_at) WHERE last_active_at IS NOT NULL;

-- ── notification_preferences ──
CREATE TABLE IF NOT EXISTS notification_preferences (
  developer_id     INTEGER PRIMARY KEY REFERENCES developers(id) ON DELETE CASCADE,
  email_enabled    BOOLEAN NOT NULL DEFAULT TRUE,
  push_enabled     BOOLEAN NOT NULL DEFAULT TRUE,
  transactional    BOOLEAN NOT NULL DEFAULT TRUE,
  social           BOOLEAN NOT NULL DEFAULT TRUE,
  digest           BOOLEAN NOT NULL DEFAULT TRUE,
  marketing        BOOLEAN NOT NULL DEFAULT FALSE,
  streak_reminders BOOLEAN NOT NULL DEFAULT TRUE,
  digest_frequency TEXT NOT NULL DEFAULT 'realtime' CHECK (digest_frequency IN ('realtime', 'hourly', 'daily', 'weekly')),
  quiet_hours_start SMALLINT,
  quiet_hours_end   SMALLINT,
  channel_overrides JSONB DEFAULT '{}',
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own preferences" ON notification_preferences
  FOR SELECT USING (
    developer_id IN (SELECT id FROM developers WHERE claimed_by = auth.uid())
  );

CREATE POLICY "Users can update own preferences" ON notification_preferences
  FOR UPDATE USING (
    developer_id IN (SELECT id FROM developers WHERE claimed_by = auth.uid())
  );

-- ── notification_batches (Knock digest pattern) ──
CREATE TABLE IF NOT EXISTS notification_batches (
  id               SERIAL PRIMARY KEY,
  batch_key        TEXT NOT NULL,
  developer_id     INTEGER NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,
  channel          TEXT NOT NULL CHECK (channel IN ('email', 'push', 'in_app')),
  closes_at        TIMESTAMPTZ NOT NULL,
  processed_at     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(batch_key, channel)
);

CREATE INDEX IF NOT EXISTS idx_batches_pending ON notification_batches (closes_at)
  WHERE processed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_batches_dev ON notification_batches (developer_id)
  WHERE processed_at IS NULL;

ALTER TABLE notification_batches ENABLE ROW LEVEL SECURITY;

-- ── notification_log (channel-agnostic, with delivery lifecycle) ──
CREATE TABLE IF NOT EXISTS notification_log (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  developer_id      INTEGER NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
  channel           TEXT NOT NULL CHECK (channel IN ('email', 'push', 'in_app')),
  notification_type TEXT NOT NULL,
  recipient         TEXT NOT NULL,
  title             TEXT NOT NULL,
  provider_id       TEXT,
  status            TEXT NOT NULL DEFAULT 'sent',
  delivered_at      TIMESTAMPTZ,
  opened_at         TIMESTAMPTZ,
  clicked_at        TIMESTAMPTZ,
  failed_at         TIMESTAMPTZ,
  failure_reason    TEXT,
  metadata          JSONB DEFAULT '{}',
  dedup_key         TEXT,
  batch_id          INTEGER REFERENCES notification_batches(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(dedup_key, channel)
);

CREATE INDEX IF NOT EXISTS idx_notification_log_dev_type ON notification_log (developer_id, notification_type);
CREATE INDEX IF NOT EXISTS idx_notification_log_dev_channel_created ON notification_log (developer_id, channel, created_at);
CREATE INDEX IF NOT EXISTS idx_notification_log_dedup ON notification_log (dedup_key, channel) WHERE dedup_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notification_log_provider ON notification_log (provider_id) WHERE provider_id IS NOT NULL;

ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;

-- ── notification_batch_items ──
CREATE TABLE IF NOT EXISTS notification_batch_items (
  id         SERIAL PRIMARY KEY,
  batch_id   INTEGER NOT NULL REFERENCES notification_batches(id) ON DELETE CASCADE,
  event_data JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_batch_items_batch ON notification_batch_items (batch_id);

ALTER TABLE notification_batch_items ENABLE ROW LEVEL SECURITY;

-- ── notification_suppressions (channel-aware) ──
CREATE TABLE IF NOT EXISTS notification_suppressions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier TEXT NOT NULL,
  channel    TEXT NOT NULL CHECK (channel IN ('email', 'push')),
  reason     TEXT NOT NULL CHECK (reason IN ('bounce', 'complaint', 'manual_unsub', 'token_expired')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(identifier, channel)
);

ALTER TABLE notification_suppressions ENABLE ROW LEVEL SECURITY;

-- ── push_subscriptions (ready for future use) ──
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  developer_id  INTEGER NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
  token         TEXT NOT NULL UNIQUE,
  platform      TEXT NOT NULL CHECK (platform IN ('web', 'ios', 'android')),
  user_agent    TEXT,
  active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_push_subs_dev ON push_subscriptions (developer_id) WHERE active = TRUE;

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own push subscriptions" ON push_subscriptions
  FOR ALL USING (
    developer_id IN (SELECT id FROM developers WHERE claimed_by = auth.uid())
  );