require "test_helper"

class GameStatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team    = teams(:warthogs)
    @season  = seasons(:winter_2026)
    @fixture = fixtures(:played_no_stats)
    sign_in_as users(:member_user)
  end

  def bulk(stats)
    post bulk_team_season_fixture_game_stats_path(@team, @season, @fixture),
         params: { game_stats: stats }
  end

  test "bulk records who played alongside the stats" do
    bulk({
      "0" => { player_id: players(:john).id, tries: 2, assists: 0, played: "1" },
      "1" => { player_id: players(:jane).id, tries: 0, assists: 0, played: "0" }
    })

    assert_equal 1, @fixture.game_stats.played.count
    assert @fixture.game_stats.find_by(player: players(:john)).played
    assert_not @fixture.game_stats.find_by(player: players(:jane)).played
  end

  test "bulk records an appearance for a player who did not score" do
    bulk({ "0" => { player_id: players(:jane).id, tries: 0, assists: 0, played: "1" } })

    stat = @fixture.game_stats.find_by(player: players(:jane))
    assert stat.played
    assert_equal 0, stat.points
  end

  test "bulk treats a recorded try as an appearance even if the box is unticked" do
    bulk({ "0" => { player_id: players(:john).id, tries: 1, assists: 0, played: "0" } })

    assert @fixture.game_stats.find_by(player: players(:john)).played
  end

  test "bulk can flip an existing appearance to absent" do
    fixture = fixtures(:played_with_stats)
    post bulk_team_season_fixture_game_stats_path(@team, @season, fixture),
         params: { game_stats: { "0" => { player_id: players(:john).id, tries: 0, assists: 0, played: "0" } } }

    assert_not game_stats(:johns_game_one).reload.played
  end

  # ── TRL CEILING ───────────────────────────────────────────────────────────

  test "bulk refuses a sheet claiming more tries than TRL published" do
    # played_no_stats is 10-2, so 10 tries is the ceiling
    bulk({
      "0" => { player_id: players(:john).id, tries: 7, assists: 0, played: "1" },
      "1" => { player_id: players(:jane).id, tries: 4, assists: 0, played: "1" }
    })

    assert_response :unprocessable_entity
    assert_equal 0, @fixture.game_stats.count
    assert_match(/10 tries/, flash[:alert])
  end

  test "a refused sheet comes back with the numbers that were typed" do
    bulk({ "0" => { player_id: players(:john).id, tries: 40, assists: 0, played: "1" } })

    # The roster is listed alphabetically, so the row index is not John's id.
    assert_select "input[name$=?][value=?]", "[tries]", "40"
  end

  test "bulk refuses more assists than TRL published tries" do
    bulk({
      "0" => { player_id: players(:john).id, tries: 5, assists: 8, played: "1" },
      "1" => { player_id: players(:jane).id, tries: 5, assists: 8, played: "1" }
    })

    assert_response :unprocessable_entity
    assert_match(/assist/i, flash[:alert])
  end

  test "bulk saves a sheet that lands exactly on TRL's score" do
    bulk({ "0" => { player_id: players(:john).id, tries: 10, assists: 10, played: "1" } })

    assert_equal 10, @fixture.reload.entered_tries
    assert @fixture.stats_verified
  end

  # ── EARLY ENTRY ───────────────────────────────────────────────────────────

  test "stats can be entered before TRL publishes a result" do
    fixture = fixtures(:upcoming)
    post bulk_team_season_fixture_game_stats_path(@team, @season, fixture),
         params: { game_stats: { "0" => { player_id: players(:john).id, tries: 6, assists: 6, played: "1" } } }

    assert_equal 6, fixture.game_stats.find_by(player: players(:john)).tries
    assert_not fixture.reload.stats_verified
  end

  test "an early sheet is saved, counted, and flagged as unchecked" do
    fixture = fixtures(:upcoming)
    post bulk_team_season_fixture_game_stats_path(@team, @season, fixture),
         params: { game_stats: { "0" => { player_id: players(:john).id, tries: 1, assists: 0, played: "1" } } }

    assert_match(/counted/i, flash[:notice])
    assert_match(/hasn't published/i, flash[:notice])
  end

  test "an early sheet lands on the team leaderboard straight away" do
    fixture = fixtures(:upcoming)
    before = Leaderboard.for(@team).find { |r| r.player == players(:john) }.points
    post bulk_team_season_fixture_game_stats_path(@team, @season, fixture),
         params: { game_stats: { "0" => { player_id: players(:john).id, tries: 3, assists: 0, played: "1" } } }

    assert_not fixture.reload.stats_verified
    assert_equal before + 6, Leaderboard.for(@team).find { |r| r.player == players(:john) }.points
  end

  test "a sheet inside TRL's score saves without the caveat" do
    bulk({ "0" => { player_id: players(:john).id, tries: 2, assists: 1, played: "1" } })

    assert_equal "Stats saved.", flash[:notice]
  end

  test "bulk is blocked for non-members" do
    sign_in_as users(:stranger)
    bulk({ "0" => { player_id: players(:john).id, tries: 5, assists: 0, played: "1" } })

    assert_equal 0, @fixture.game_stats.count
    assert_redirected_to team_path(@team)
  end
end
