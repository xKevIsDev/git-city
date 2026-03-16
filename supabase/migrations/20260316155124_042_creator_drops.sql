-- Creator Drops: admin plants drops on buildings, players explore and pull for points

-- building_drops: drops planted by admin
CREATE TABLE IF NOT EXISTS building_drops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  building_id BIGINT NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
  rarity TEXT NOT NULL CHECK (rarity IN ('common','rare','epic','legendary')),
  points INTEGER NOT NULL,
  item_reward TEXT REFERENCES items(id),
  max_pulls INTEGER NOT NULL DEFAULT 50,
  pull_count INTEGER NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by TEXT NOT NULL DEFAULT 'srizzon'
);

-- 1 non-exhausted drop per building (expiration checked in app code)
CREATE UNIQUE INDEX IF NOT EXISTS idx_building_drops_active_building
  ON building_drops (building_id) WHERE pull_count < max_pulls;

-- filter by expiration (queries add WHERE expires_at > now() at runtime)
CREATE INDEX IF NOT EXISTS idx_building_drops_expires
  ON building_drops (expires_at);

-- drop_pulls: player pulls
CREATE TABLE IF NOT EXISTS drop_pulls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  drop_id UUID NOT NULL REFERENCES building_drops(id) ON DELETE CASCADE,
  developer_id BIGINT NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
  points_earned INTEGER NOT NULL,
  pulled_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_drop_pulls_unique ON drop_pulls (drop_id, developer_id);
CREATE INDEX IF NOT EXISTS idx_drop_pulls_leaderboard ON drop_pulls (developer_id, points_earned);
CREATE INDEX IF NOT EXISTS idx_drop_pulls_drop ON drop_pulls (drop_id);

-- RLS
ALTER TABLE building_drops ENABLE ROW LEVEL SECURITY;
ALTER TABLE drop_pulls ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Building drops are viewable by everyone" ON building_drops;
CREATE POLICY "Building drops are viewable by everyone" ON building_drops FOR SELECT USING (true);
DROP POLICY IF EXISTS "Drop pulls are viewable by everyone" ON drop_pulls;
CREATE POLICY "Drop pulls are viewable by everyone" ON drop_pulls FOR SELECT USING (true);