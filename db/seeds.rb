# Demo data for local development: an admin you can sign in as, a squad, two
# seasons of fixtures, and the stats behind them.
#
#   bin/rails db:seed
#   DEMO_EMAIL=me@example.com DEMO_PASSWORD=hunter2 bin/rails db:seed
#
# Safe to run repeatedly — users, the team and the roster are matched on their
# natural keys, and the seasons are rebuilt from scratch each time.
unless Rails.env.development?
  puts "Skipping demo seeds — they only run in development."
  return
end

demo_email    = ENV.fetch("DEMO_EMAIL", "demo@touchline.test")
demo_password = ENV.fetch("DEMO_PASSWORD", "password")

# Deterministic, so a re-run gives you the same league table you had before.
rng = Random.new(1908)

def upsert_user(email, name, password)
  User.find_or_initialize_by(email_address: email).tap do |user|
    user.name = name
    user.password = password
    user.password_confirmation = password
    user.save!
  end
end

# ── People ────────────────────────────────────────────────────────────────
you     = upsert_user(demo_email, "Jamie Whitlock", demo_password)
teammate = upsert_user("riley@touchline.test", "Riley Okafor", "password")
hopeful  = upsert_user("casey@touchline.test", "Casey Nolan", "password")

# ── Team ──────────────────────────────────────────────────────────────────
team = Team.find_or_create_by!(name: "Bardon Warthogs") do |t|
  t.location          = "Brisbane"
  t.trl_location_slug = "brisbane"
  t.spawtz_venue_id   = "200025"
  t.spawtz_league_id  = "200082"
  t.spawtz_season_id  = "1400063"
  t.spawtz_team_id    = "demo-warthogs"
end
team.update!(fixtures_synced_at: 2.hours.ago)

{ you => [ :admin, :accepted ], teammate => [ :member, :accepted ], hopeful => [ :member, :pending ] }
  .each do |user, (role, status)|
    membership = team.team_memberships.find_or_initialize_by(user: user)
    membership.update!(role: role, status: status)
  end

# ── Roster ────────────────────────────────────────────────────────────────
# Two entries are claimed by real accounts; one is waiting on an email so you
# can see the auto-link state on the roster.
roster = {
  "Jamie"  => { user: you },
  "Riley"  => { user: teammate },
  "Casey"  => {},
  "Jordan" => {},
  "Alex"   => {},
  "Morgan" => {},
  "Sam"    => {},
  "Toby"   => {},
  "Nina"   => {},
  "Priya"  => {},
  "Tom H"  => { email: "tomh@touchline.test" }
}

players = roster.map do |name, attrs|
  player = team.players.find_or_initialize_by(name: name)
  player.update!(user: attrs[:user], email: attrs[:email])
  player
end
team.players.where.not(id: players.map(&:id)).destroy_all

# ── Seasons and fixtures ──────────────────────────────────────────────────
# Rebuilt every run so the numbers stay consistent with the code above.
team.seasons.destroy_all

OPPONENTS = [
  "WGD 13+", "51 Shades of Shape", "Try Hards", "Panthers",
  "Bandits", "Sharks", "Rolling Maul", "Kick and Chase"
].freeze

# TRL scores a try as one point, so the scoreline is the ceiling on the tries
# a sheet can claim. Hand out exactly that many, then a lighter spread of
# assists, so every fixture verifies against its own result.
def spread(total, count, rng)
  Array.new(count, 0).tap do |shares|
    total.times { shares[rng.rand(count)] += 1 }
  end
end

# tries: how many to hand out, defaulting to TRL's score. Passed explicitly for
# a fixture entered before TRL published one.
#
# Every try is a row, and an assist is a column on the try it produced — so an
# assisted try picks its passer out of the rest of the squad, and nobody
# assists themselves. Whoever took the field gets an Appearance; whoever did
# not gets no row at all, because the row's existence is the fact.
def record_stats(fixture, squad, _absent, rng, tries: nil)
  our = tries || fixture.our_score
  scorers = spread(our, squad.size, rng)
  assisted = rng.rand(0..our)

  squad.each { |player| fixture.appearances.create!(player: player) }

  scorers.each_with_index do |count, i|
    count.times do
      assister = (squad - [ squad[i] ]).sample(random: rng) if assisted.positive?
      assisted -= 1 if assister
      fixture.touchdowns.create!(scorer: squad[i], assister: assister)
    end
  end

  # TRL restarts with a bomb at the start of each half and after every try, so
  # a team receives four or five in a game and each one is caught or dropped by
  # somebody. An opposition assist is much rarer, and never more than the other
  # side actually scored.
  rng.rand(4..5).times do
    fixture.plays.create!(player: squad.sample(random: rng),
                          kind: rng.rand(100) < 75 ? :bomb_catch : :dropped_bomb)
  end

  rng.rand(0..[ fixture.opponent_score.to_i, 2 ].min).times do
    fixture.plays.create!(player: squad.sample(random: rng), kind: :opposition_assist)
  end

  fixture.refresh_stats_verification!
end

seasons = [
  { name: "Bardon Mondays - 2025 Summer", created_at: 11.months.ago, starts: 48.weeks.ago, games: 6, live: false },
  { name: "Bardon Mondays - 2026 Winter", created_at: 4.months.ago,  starts: 16.weeks.ago, games: 6, live: true }
]

seasons.each do |spec|
  season = team.seasons.create!(name: spec[:name], created_at: spec[:created_at],
                                spawtz_season_id: rng.rand(1_000_000..1_999_999).to_s)

  spec[:games].times do |week|
    fixture = season.fixtures.create!(
      opponent_name: OPPONENTS[(week + spec[:games]) % OPPONENTS.size],
      date: spec[:starts] + week.weeks,
      our_score: rng.rand(4..12),
      opponent_score: rng.rand(0..9)
    )

    squad = players.sample(rng.rand(8..10), random: rng)
    record_stats(fixture, squad, players - squad, rng)
  end

  next unless spec[:live]

  # Last week's game: played, result is in, nobody has entered the sheet yet.
  # This is what drives the "Stats not entered yet" prompt on the home screen.
  season.fixtures.create!(
    opponent_name: "Brisbane Bandits",
    date: 1.week.ago,
    our_score: 9,
    opponent_score: 4
  ).refresh_stats_verification!

  # Monday night's game: the sheet went in on the drive home, TRL has not
  # posted the result yet. Shows the "awaiting TRL" state — saved and visible,
  # but held out of the leaderboard until the result lands and matches.
  early = season.fixtures.create!(opponent_name: "Ashgrove Owls", date: 2.days.ago)
  early_squad = players.sample(9, random: rng)
  record_stats(early, early_squad, players - early_squad, rng, tries: 7)

  # And one still to play.
  season.fixtures.create!(opponent_name: "Kenmore Kings", date: 6.days.from_now)
end

# ── Progression ───────────────────────────────────────────────────────────
# Accolades are awarded, never computed, so the demo has to run the ledger for
# them to exist. Then a title and a showcase, because an empty slot teaches
# nothing about what the slot is for.
User.where(id: team.players.select(:user_id)).find_each do |user|
  AccoladeLedger.settle(user)

  earned = Progression.new(user).earned.map { |accolade, _count| accolade.key }
  next if earned.empty?

  user.update!(title_key: earned.first, showcase_keys: earned.first(Progression::SHOWCASE_SLOTS))
end

puts <<~SUMMARY

  Demo data ready.

    Sign in    #{demo_email}
    Password   #{demo_password}

    #{team.name} — #{team.players.count} players, #{team.seasons.count} seasons, #{team.fixtures.count} fixtures
    #{Touchdown.count} touchdowns · #{Play.count} plays · #{Appearance.count} appearances · #{team.team_memberships.pending.count} pending join request
    #{AccoladeAward.count} accolades awarded · #{team.players.filter_map(&:user).map { |u| "#{u.name.split.first} is level #{Progression.new(u).level}" }.to_sentence}

  Also seeded: riley@touchline.test (member) and casey@touchline.test (pending), both with password "password".
SUMMARY
