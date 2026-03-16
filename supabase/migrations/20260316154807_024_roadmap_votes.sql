-- Roadmap feature voting
create table if not exists roadmap_votes (
  id bigint generated always as identity primary key,
  developer_id bigint not null references developers(id) on delete cascade,
  item_id text not null,
  created_at timestamptz not null default now(),
  unique(developer_id, item_id)
);

create index if not exists idx_roadmap_votes_item on roadmap_votes(item_id);

alter table roadmap_votes enable row level security;

-- Public read for vote counts
create policy "Anyone can read votes"
  on roadmap_votes for select using (true);