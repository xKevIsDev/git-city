-- Add github_login to sky_ad_events so we know which logged-in user
-- triggered the event (nullable — anonymous visitors won't have it).
alter table sky_ad_events add column if not exists github_login text;

create index if not exists idx_sky_ad_events_login on sky_ad_events(github_login)
  where github_login is not null;