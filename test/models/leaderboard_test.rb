require "test_helper"

class LeaderboardTest < ActiveSupport::TestCase
  setup { @team = teams(:warthogs) }

  # A season built one round at a time: each entry is a game, mapping Players to
  # the [tries, assists] they put up in it. Games run a week apart in order, so
  # "most recent" means the last entry.
  def season_of(*games)
    season = @team.seasons.create!(name: "Movement Test Season")
    games.each_with_index do |lineup, round|
      fixture = season.fixtures.create!(
        opponent_name: "Round #{round + 1}",
        date: Time.zone.parse("2026-07-06 19:40") + (round * 7).days
      )
      lineup.each do |player, (tries, assists)|
        fixture.game_stats.create!(player: player, tries: tries, assists: assists, played: true)
      end
    end
    season
  end

  def board_for(season)
    Leaderboard.for(@team, season: season).index_by { |row| row.player.name }
  end

  test "all time totals span every season" do
    row = Leaderboard.for(@team).find { |r| r.player == players(:john) }

    assert_equal 8, row.tries
    assert_equal 5, row.assists
    assert_equal 3, row.games
    assert_equal 21, row.points
  end

  test "a season is scoped to that season's fixtures" do
    row = Leaderboard.for(@team, season: seasons(:winter_2026)).find { |r| r.player == players(:john) }

    assert_equal 7, row.tries
    assert_equal 3, row.assists
    assert_equal 2, row.games
  end

  test "excludes players with no appearance in the season" do
    # Jane was named for the winter game but did not take the field
    names = Leaderboard.for(@team, season: seasons(:winter_2026)).map { |r| r.player.name }

    assert_equal [ "John" ], names
  end

  test "includes a player who appeared without scoring" do
    names = Leaderboard.for(@team, season: seasons(:summer_2025)).map { |r| r.player.name }

    assert_includes names, "Jane"
  end

  test "ranks by points descending" do
    points = Leaderboard.for(@team).map(&:points)

    assert_equal points.sort.reverse, points
  end

  # ── TRL VERIFICATION ──────────────────────────────────────────────────────

  # A Team's own board is its own record: everything counts the moment it is
  # entered. TRL verification is reserved for the cross-team social league.

  test "stats entered before TRL published the result are ranked straight away" do
    # John's 4T 2A on awaiting_trl is on the board with the rest
    row = Leaderboard.for(@team).find { |r| r.player == players(:john) }

    assert_equal 8, row.tries
    assert_equal 3, row.games
  end

  test "a result landing does not move the board" do
    before = Leaderboard.for(@team).map { |r| [ r.player.name, r.points ] }
    fixtures(:awaiting_trl).update!(our_score: 4, opponent_score: 3)
    fixtures(:awaiting_trl).refresh_stats_verification!

    assert_equal before, Leaderboard.for(@team).map { |r| [ r.player.name, r.points ] }
  end

  test "a sheet that overruns TRL's result stays on the board" do
    fixtures(:played_with_stats).update!(our_score: 1, opponent_score: 0)
    fixtures(:played_with_stats).refresh_stats_verification!

    row = Leaderboard.for(@team).find { |r| r.player == players(:john) }

    assert_not fixtures(:played_with_stats).stats_verified
    assert_equal 8, row.tries
    assert_equal 3, row.games
  end

  # ── MOVEMENT SINCE THE LAST GAME ──────────────────────────────────────────

  test "movement is the places gained since the game before last" do
    season = season_of(
      { players(:john) => [ 3, 0 ], players(:jane) => [ 1, 0 ] }, # John 6, Jane 2
      { players(:john) => [ 0, 0 ], players(:jane) => [ 5, 0 ] }  # John 6, Jane 12
    )

    board = board_for(season)

    assert_equal 1, board["Jane"].movement
    assert_equal(-1, board["John"].movement)
  end

  test "movement is zero for a player who held their place" do
    season = season_of(
      { players(:john) => [ 3, 0 ], players(:jane) => [ 1, 0 ] },
      { players(:john) => [ 1, 0 ], players(:jane) => [ 0, 0 ] }
    )

    board = board_for(season)

    assert_equal 0, board["John"].movement
    assert_equal 0, board["Jane"].movement
  end

  test "there is no movement to report on the opening game of a season" do
    row = Leaderboard.for(@team, season: season_of({ players(:john) => [ 2, 0 ] })).sole

    assert_nil row.movement
    assert row.new_entry?
  end

  test "a player debuting in the last game has no position to have moved from" do
    season = season_of(
      { players(:john) => [ 3, 0 ] },
      { players(:john) => [ 0, 0 ], players(:jane) => [ 1, 0 ] }
    )

    board = board_for(season)

    assert_nil board["Jane"].movement
    assert_equal 0, board["John"].movement
  end

  # ── SCORING STREAK ────────────────────────────────────────────────────────

  test "a try in three straight games lights the flame" do
    season = season_of(
      { players(:john) => [ 1, 0 ] }, { players(:john) => [ 2, 0 ] }, { players(:john) => [ 1, 0 ] }
    )

    row = Leaderboard.for(@team, season: season).sole

    assert row.hot?
    assert_equal 3, row.streak
  end

  test "two straight games is not yet a streak" do
    season = season_of({ players(:john) => [ 1, 0 ] }, { players(:john) => [ 2, 0 ] })

    assert_not Leaderboard.for(@team, season: season).sole.hot?
  end

  test "a scoreless game puts the flame out" do
    season = season_of(
      { players(:john) => [ 1, 0 ] }, { players(:john) => [ 2, 0 ] },
      { players(:john) => [ 1, 0 ] }, { players(:john) => [ 0, 0 ] }
    )

    row = Leaderboard.for(@team, season: season).sole

    assert_not row.hot?
    assert_equal 0, row.streak
  end

  test "the streak counts back only from the most recent game" do
    season = season_of(
      { players(:john) => [ 1, 0 ] }, { players(:john) => [ 1, 0 ] }, { players(:john) => [ 1, 0 ] },
      { players(:john) => [ 0, 0 ] }, { players(:john) => [ 2, 0 ] }
    )

    row = Leaderboard.for(@team, season: season).sole

    assert_equal 1, row.streak
    assert_not row.hot?
  end

  test "assists alone do not light the flame" do
    season = season_of(
      { players(:john) => [ 0, 2 ] }, { players(:john) => [ 0, 3 ] }, { players(:john) => [ 0, 1 ] }
    )

    row = Leaderboard.for(@team, season: season).sole

    assert_equal 0, row.streak
    assert_not row.hot?
  end

  test "a game missed altogether does not break a run" do
    season = season_of(
      { players(:john) => [ 1, 0 ] },
      { players(:jane) => [ 1, 0 ] }, # John was not on this sheet at all
      { players(:john) => [ 1, 0 ] }, { players(:john) => [ 1, 0 ] }
    )

    assert_equal 3, board_for(season)["John"].streak
  end
end
