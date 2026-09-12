# A ranking of a Team's Players by points, over a single Season or all time.
# Only Players with at least one appearance appear on it.
#
# This is the Team's own board, so it counts Plays: a bomb catch is worth a
# point here and a dropped bomb costs one. The Social league is the board that
# cannot — see StatLine#touchdown_points.
class Leaderboard
  # Three straight games with a try is a run worth marking on the board; two is
  # just a good fortnight.
  HOT_STREAK = 3

  # What each counted thing is worth, keyed by the tally that holds it.
  POINTS = {
    tries:              Touchdown::TRY_POINTS,
    assists:            Touchdown::ASSIST_POINTS,
    bomb_catches:       Play::POINTS[:bomb_catch],
    dropped_bombs:      Play::POINTS[:dropped_bomb],
    opposition_assists: Play::POINTS[:opposition_assist]
  }.freeze

  # Play kinds are named for one occurrence; a tally counts many.
  TALLIES = Play::POINTS.keys.index_with { |kind| :"#{kind.to_s.pluralize}" }.freeze

  def self.points_for(totals) = POINTS.sum { |tally, value| totals[tally].to_i * value }

  Row = Struct.new(:player, :tries, :assists, :bomb_catches, :dropped_bombs,
                   :opposition_assists, :games, :movement, :streak, keyword_init: true) do
    def points = Leaderboard.points_for(to_h)

    # Both negatives under one column: they stack, so this can exceed the number
    # of distinct incidents.
    def negative_plays = dropped_bombs + opposition_assists

    # Places gained since the game before last, positive upward. Nil when there
    # is no earlier position to measure against — a debut, or every row on the
    # opening game of a season.
    def new_entry? = movement.nil?

    def hot? = streak >= HOT_STREAK
  end

  # One Player's game: everything the board counts off, gathered per appearance
  # so movement and streaks can be measured game by game.
  Entry = Struct.new(:player_id, :fixture_id, :date, :tries, :assists,
                     :bomb_catches, :dropped_bombs, :opposition_assists, :appeared) do
    def points = Leaderboard.points_for(to_h)
  end

  # season: nil ranks every season the Team has played.
  #
  # Every appearance counts the moment it is entered, verified or not. A Team's
  # board is its own record of its own games — the point of entering stats on
  # the drive home is seeing them land. TRL verification gates the cross-team
  # social league instead, where one team's unchecked sheet would distort
  # everybody else's standing; see Fixture.verified.
  def self.for(team, season: nil)
    fixtures = season ? Fixture.where(season_id: season.id) : Fixture.where(season_id: team.seasons.select(:id))

    entries = collect(fixtures, team.players.select(:id))
    return [] if entries.empty?

    players   = team.players.index_by(&:id)
    last_game = entries.max_by(&:date).fixture_id
    previous  = positions(entries.reject { |entry| entry.fixture_id == last_game }, players)
    runs      = scoring_runs(entries)

    standings(entries, players).map.with_index(1) do |(player_id, totals), position|
      Row.new(
        player: players[player_id],
        movement: previous[player_id]&.-(position),
        streak: runs.fetch(player_id, 0),
        **totals
      )
    end
  end

  # Appearances, tries, assists and Plays, folded into one entry per Player per
  # Fixture. The board needs each game separately — movement is the standing
  # re-run without the last one, and a streak is counted back game by game — so
  # there is nothing here an aggregate could do in fewer round trips.
  def self.collect(fixtures, player_ids)
    dates = fixtures.pluck(:id, :date).to_h
    return [] if dates.empty?

    fixture_ids = dates.keys
    entries = Hash.new do |hash, key|
      hash[key] = Entry.new(key.first, key.last, dates[key.last], 0, 0, 0, 0, 0, false)
    end

    Appearance.where(player_id: player_ids, fixture_id: fixture_ids)
              .pluck(:player_id, :fixture_id)
              .each { |key| entries[key].appeared = true }

    Touchdown.where(fixture_id: fixture_ids, scorer_player_id: player_ids)
             .pluck(:scorer_player_id, :fixture_id)
             .each { |key| entries[key].tries += 1 }

    Touchdown.where(fixture_id: fixture_ids, assister_player_id: player_ids)
             .pluck(:assister_player_id, :fixture_id)
             .each { |key| entries[key].assists += 1 }

    Play.where(fixture_id: fixture_ids, player_id: player_ids)
        .pluck(:player_id, :fixture_id, :kind)
        .each { |player_id, fixture_id, kind| entries[[ player_id, fixture_id ]][TALLIES.fetch(kind.to_sym)] += 1 }

    # An appearance is what puts a Player on the board. Every write the app makes
    # records one, so a stat without one is imported history missing its game —
    # and ranking somebody off a game we cannot say they played is worse than
    # leaving the row out.
    entries.values.select(&:appeared)
  end
  private_class_method :collect

  # [player_id, totals] in board order: points, then tries, then assists, then
  # name, so a tie always lands the same way round. Movement is measured by
  # re-running this over a smaller set of entries, and it would report a phantom
  # move if two level players could swap places between runs.
  def self.standings(entries, players)
    entries.group_by(&:player_id).map { |player_id, list|
      [ player_id, {
        tries:              list.sum(&:tries),
        assists:            list.sum(&:assists),
        bomb_catches:       list.sum(&:bomb_catches),
        dropped_bombs:      list.sum(&:dropped_bombs),
        opposition_assists: list.sum(&:opposition_assists),
        games:              list.count(&:appeared)
      } ]
    }.sort_by { |player_id, totals|
      [ -points_for(totals), -totals[:tries], -totals[:assists], players[player_id].name ]
    }
  end
  private_class_method :standings

  def self.positions(entries, players)
    standings(entries, players).each_with_index.to_h { |(player_id, _totals), i| [ player_id, i + 1 ] }
  end
  private_class_method :positions

  # Counted back from the most recent appearance, so the flame only ever marks
  # a run that is still alive: three in a row back in May, followed by a month
  # of blanks, is history rather than form. Tries only — an assist is somebody
  # else's name on the scoresheet.
  def self.scoring_runs(entries)
    entries.group_by(&:player_id).transform_values do |list|
      list.sort_by(&:date).reverse.take_while { |entry| entry.tries.positive? }.size
    end
  end
  private_class_method :scoring_runs
end
