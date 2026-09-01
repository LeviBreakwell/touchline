# A ranking of a Team's Players by points, over a single Season or all time.
# Only Players with at least one appearance appear on it.
class Leaderboard
  # Three straight games with a try is a run worth marking on the board; two is
  # just a good fortnight.
  HOT_STREAK = 3

  Row = Struct.new(:player, :tries, :assists, :games, :movement, :streak, keyword_init: true) do
    def points = (tries * 2) + assists

    # Places gained since the game before last, positive upward. Nil when there
    # is no earlier position to measure against — a debut, or every row on the
    # opening game of a season.
    def new_entry? = movement.nil?

    def hot? = streak >= HOT_STREAK
  end

  # One Player's appearance in one Fixture: the raw material the board is
  # counted off.
  Appearance = Struct.new(:player_id, :fixture_id, :date, :tries, :assists)

  # season: nil ranks every season the Team has played.
  #
  # Every appearance counts the moment it is entered, verified or not. A Team's
  # board is its own record of its own games — the point of entering stats on
  # the drive home is seeing them land. TRL verification gates the cross-team
  # social league instead, where one team's unchecked sheet would distort
  # everybody else's standing; see Fixture.verified and GameStat.verified.
  def self.for(team, season: nil)
    scope = GameStat.played
                    .where(player_id: team.players.select(:id))
                    .joins(:fixture)
    scope = scope.where(fixtures: { season_id: season.id }) if season

    # Every appearance is pulled once and the three things the board needs —
    # totals, the standing before the last game, and each Player's current run
    # — are counted off it in memory. Asked as three aggregates that would be
    # three round trips to say one thing about a few hundred rows.
    appearances = scope.pluck(Arel.sql(<<~SQL.squish)).map { |row| Appearance.new(*row) }
      game_stats.player_id, fixtures.id, fixtures.date, game_stats.tries, game_stats.assists
    SQL
    return [] if appearances.empty?

    players   = team.players.index_by(&:id)
    last_game = appearances.max_by(&:date).fixture_id
    previous  = positions(appearances.reject { |a| a.fixture_id == last_game }, players)
    runs      = scoring_runs(appearances)

    standings(appearances, players).map.with_index(1) do |(player_id, tries, assists, games), position|
      Row.new(
        player: players[player_id],
        tries: tries,
        assists: assists,
        games: games,
        movement: previous[player_id]&.-(position),
        streak: runs.fetch(player_id, 0)
      )
    end
  end

  # [player_id, tries, assists, games] in board order: points, then tries, then
  # assists, then name, so a tie always lands the same way round. Movement is
  # measured by re-running this over a smaller set of appearances, and it would
  # report a phantom move if two level players could swap places between runs.
  def self.standings(appearances, players)
    appearances.group_by(&:player_id).map { |player_id, list|
      [ player_id, list.sum(&:tries), list.sum(&:assists), list.size ]
    }.sort_by { |player_id, tries, assists, _games|
      [ -((tries * 2) + assists), -tries, -assists, players[player_id].name ]
    }
  end
  private_class_method :standings

  def self.positions(appearances, players)
    standings(appearances, players).each_with_index.to_h { |(player_id, *), i| [ player_id, i + 1 ] }
  end
  private_class_method :positions

  # Counted back from the most recent appearance, so the flame only ever marks
  # a run that is still alive: three in a row back in May, followed by a month
  # of blanks, is history rather than form. Tries only — an assist is somebody
  # else's name on the scoresheet.
  def self.scoring_runs(appearances)
    appearances.group_by(&:player_id).transform_values do |list|
      list.sort_by(&:date).reverse.take_while { |appearance| appearance.tries.positive? }.size
    end
  end
  private_class_method :scoring_runs
end
