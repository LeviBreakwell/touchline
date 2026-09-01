# A tally of a Player's tries, assists, appearances and seasons over some set of
# GameStats, with the averages that fall out of it. Built by StatLine.for so the
# same aggregation serves a season, a career, or anything in between.
class StatLine
  attr_reader :tries, :assists, :games, :seasons

  # Only appearances count — a GameStat with played false records that the
  # Player did not take the field, so it contributes nothing to a stat line.
  # Verification is deliberately not a filter here: a Player's own totals move
  # the moment a Member enters the sheet. Only the cross-team social league
  # waits on TRL — see StatLine.unconfirmed for the slice it will exclude.
  def self.for(game_stats)
    build(game_stats.played.joins(:fixture))
  end

  # The part of a stat line TRL has not confirmed. Counted in .for like
  # everything else; broken out so a Player can see which of their stats is
  # still unchecked, and so the social league can subtract it.
  def self.unconfirmed(game_stats)
    build(game_stats.played.joins(:fixture).where(fixtures: { stats_verified: false }))
  end

  def self.build(scope)
    tries, assists, games, seasons = scope.pick(Arel.sql(<<~SQL.squish))
      COALESCE(SUM(game_stats.tries), 0),
      COALESCE(SUM(game_stats.assists), 0),
      COUNT(*),
      COUNT(DISTINCT fixtures.season_id)
    SQL

    new(tries: tries.to_i, assists: assists.to_i, games: games.to_i, seasons: seasons.to_i)
  end
  private_class_method :build

  def initialize(tries: 0, assists: 0, games: 0, seasons: 0)
    @tries = tries
    @assists = assists
    @games = games
    @seasons = seasons
  end

  def points = (tries * 2) + assists

  def any? = games.positive?

  def tries_per_game   = per(tries, games)
  def assists_per_game = per(assists, games)
  def points_per_game  = per(points, games)

  def tries_per_season   = per(tries, seasons)
  def assists_per_season = per(assists, seasons)
  def points_per_season  = per(points, seasons)
  def games_per_season   = per(games, seasons)

  private

  def per(total, count)
    return 0.0 if count.zero?
    (total.to_f / count).round(1)
  end
end
