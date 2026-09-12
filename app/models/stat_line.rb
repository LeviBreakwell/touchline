# A tally of a Player's tries, assists, Plays, appearances and seasons over some
# slice of the record, with the averages that fall out of it. The same object
# serves a season, a career, or anything in between.
#
# Nothing here is stored: tries are counted off Touchdowns, games off
# Appearances. Verification is deliberately not a filter — a Player's own totals
# move the moment a Member enters them. Only the cross-team Social league waits
# on TRL, and .unconfirmed is the slice it subtracts.
class StatLine
  attr_reader :tries, :assists, :games, :seasons, :plays

  # players:  a Player, an id, an array of either, or a relation
  # fixtures: the slice of the record to count over — a season, or everything
  def self.for(players, fixtures: Fixture.all)
    build(players, fixtures)
  end

  # The part of a stat line TRL has not confirmed. Counted in .for like
  # everything else; broken out so a Player can see which of their stats is
  # still unchecked.
  def self.unconfirmed(players, fixtures: Fixture.all)
    build(players, fixtures.where(stats_verified: false))
  end

  def self.build(players, fixtures)
    fixture_ids = fixtures.select(:id)

    games, seasons = Appearance.where(player_id: players, fixture_id: fixture_ids)
                               .joins(:fixture)
                               .pick(Arel.sql("COUNT(*), COUNT(DISTINCT fixtures.season_id)"))

    new(
      tries:   Touchdown.where(fixture_id: fixture_ids, scorer_player_id: players).count,
      assists: Touchdown.where(fixture_id: fixture_ids, assister_player_id: players).count,
      plays:   Play.where(fixture_id: fixture_ids, player_id: players).group(:kind).count,
      games:   games.to_i,
      seasons: seasons.to_i
    )
  end
  private_class_method :build

  def initialize(tries: 0, assists: 0, games: 0, seasons: 0, plays: {})
    @tries = tries
    @assists = assists
    @games = games
    @seasons = seasons
    @plays = plays
  end

  def bomb_catches       = plays.fetch("bomb_catch", 0)
  def dropped_bombs      = plays.fetch("dropped_bomb", 0)
  def opposition_assists = plays.fetch("opposition_assist", 0)

  # One column on a card, because both cost points and both are the same kind of
  # thing to the person reading it. They stack — a dropped bomb the opposition
  # scored from is both — so this can exceed the number of distinct incidents.
  def negative_plays = dropped_bombs + opposition_assists

  # Every kick-off a Player contests produces exactly one or the other, which is
  # what makes this a rate rather than a guess. Nil until they have contested
  # one: 0% and "never went up for it" are not the same statement.
  def catch_rate
    contested = bomb_catches + dropped_bombs
    return nil if contested.zero?
    (bomb_catches.to_f / contested * 100).round
  end

  # What the Social league ranks on: Touchdowns alone, since Plays are
  # Team-local. A Player therefore has two point totals and any surface showing
  # one has to say which.
  def touchdown_points = (tries * Touchdown::TRY_POINTS) + (assists * Touchdown::ASSIST_POINTS)

  def play_points = plays.sum { |kind, count| Play::POINTS.fetch(kind.to_sym) * count }

  # The Team-inclusive total, and the one a Team's own board ranks on.
  def points = touchdown_points + play_points

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
