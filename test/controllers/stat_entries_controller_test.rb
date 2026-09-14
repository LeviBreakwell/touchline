require "test_helper"

# The three writers behind the match ladder. Every gesture is one row: there is
# no sheet, no submit, and nothing is ever refused for overrunning TRL.
class StatEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team    = teams(:warthogs)
    @season  = seasons(:winter_2026)
    @fixture = fixtures(:played_no_stats)   # TRL has this at 10, nothing entered
    sign_in_as users(:member_user)
  end

  def post_json(path, body)
    post path, params: body.to_json, headers: { "CONTENT_TYPE" => "application/json" }
  end

  def touchdowns_path(fixture = @fixture) = team_season_fixture_touchdowns_path(@team, @season, fixture)
  def plays_path(fixture = @fixture)      = team_season_fixture_plays_path(@team, @season, fixture)
  def appearances_path(fixture = @fixture) = team_season_fixture_appearances_path(@team, @season, fixture)
  def latest_touchdown_path(fixture = @fixture) = team_season_fixture_latest_touchdown_path(@team, @season, fixture)
  def latest_play_path(fixture = @fixture)      = team_season_fixture_latest_play_path(@team, @season, fixture)

  # ── TRIES AND ASSISTS ─────────────────────────────────────────────────────

  test "a tap is a try" do
    assert_difference -> { @fixture.touchdowns.count }, 1 do
      post_json touchdowns_path, scorer_player_id: players(:john).id
    end

    assert_response :success
    touchdown = @fixture.touchdowns.sole
    assert_equal players(:john), touchdown.scorer
    assert_nil touchdown.assister
  end

  test "a drag is one row carrying both names" do
    post_json touchdowns_path, scorer_player_id: players(:john).id, assister_player_id: players(:jane).id

    assert_response :success
    touchdown = @fixture.touchdowns.sole
    assert_equal players(:john), touchdown.scorer
    assert_equal players(:jane), touchdown.assister
    assert_equal 1, @fixture.entered_tries
    assert_equal 1, @fixture.entered_assists
  end

  test "a try cannot be assisted by the player who scored it" do
    post_json touchdowns_path, scorer_player_id: players(:john).id, assister_player_id: players(:john).id

    assert_response :unprocessable_entity
    assert_equal 0, @fixture.touchdowns.count
  end

  test "the answer is the ladder as it now stands" do
    post_json touchdowns_path, scorer_player_id: players(:john).id

    body = JSON.parse(response.body)
    assert_includes body["ladder"], "lcard"
    assert_equal "John — try +8", body["toast"]
    assert_includes body.dig("undo", "path"), "/touchdowns/"
  end

  test "undo is deleting the row" do
    post_json touchdowns_path, scorer_player_id: players(:john).id
    undo = JSON.parse(response.body).dig("undo", "path")

    assert_difference -> { @fixture.touchdowns.count }, -1 do
      delete undo
    end
    assert_response :success
  end

  # ── THE HOLD MENU'S REMOVE ITEMS ──────────────────────────────────────────

  test "removing a try takes the whole row, assist included" do
    post_json touchdowns_path, scorer_player_id: players(:john).id, assister_player_id: players(:jane).id

    assert_difference -> { @fixture.touchdowns.count }, -1 do
      delete latest_touchdown_path, params: { player_id: players(:john).id, role: "scorer" }
    end
    assert_response :success
    assert_equal 0, @fixture.entered_tries
    assert_equal 0, @fixture.entered_assists
  end

  test "removing an assist takes the same row, by the other name" do
    post_json touchdowns_path, scorer_player_id: players(:john).id, assister_player_id: players(:jane).id

    assert_difference -> { @fixture.touchdowns.count }, -1 do
      delete latest_touchdown_path, params: { player_id: players(:jane).id, role: "assister" }
    end
    assert_response :success
    assert_equal 0, @fixture.entered_tries
  end

  test "several tries for the same player: removing one leaves the rest" do
    2.times { post_json touchdowns_path, scorer_player_id: players(:john).id }

    assert_difference -> { @fixture.touchdowns.count }, -1 do
      delete latest_touchdown_path, params: { player_id: players(:john).id, role: "scorer" }
    end
    assert_equal 1, @fixture.touchdowns.count
  end

  test "a role that isn't scorer or assister is refused" do
    post_json touchdowns_path, scorer_player_id: players(:john).id

    delete latest_touchdown_path, params: { player_id: players(:john).id, role: "referee" }

    assert_response :unprocessable_entity
    assert_equal 1, @fixture.touchdowns.count
  end

  test "removing a try when that player has none is a no-op, not an error" do
    delete latest_touchdown_path, params: { player_id: players(:john).id, role: "scorer" }

    assert_response :success
  end

  test "removing a play takes the most recent occurrence" do
    2.times { post_json plays_path, player_id: players(:john).id, kind: "dropped_bomb" }

    assert_difference -> { @fixture.plays.count }, -1 do
      delete latest_play_path, params: { player_id: players(:john).id, kind: "dropped_bomb" }
    end
    assert_equal 1, @fixture.plays.count
  end

  test "removing a play never touches verification" do
    post_json plays_path, player_id: players(:john).id, kind: "dropped_bomb"

    delete latest_play_path, params: { player_id: players(:john).id, kind: "dropped_bomb" }

    assert @fixture.reload.stats_verified
  end

  test "a play kind the app does not record is refused when removing" do
    delete latest_play_path, params: { player_id: players(:john).id, kind: "spilt_milk" }

    assert_response :unprocessable_entity
  end

  # ── GOING PAST TRL ────────────────────────────────────────────────────────

  test "going past TRL's score is recorded and flagged, never refused" do
    11.times { post_json touchdowns_path, scorer_player_id: players(:john).id }

    assert_response :success
    assert_equal 11, @fixture.entered_tries        # TRL has the game at 10
    assert_not @fixture.reload.stats_verified
    assert_equal :over_official, @fixture.stats_status
  end

  test "entering inside TRL's score verifies the fixture" do
    post_json touchdowns_path, scorer_player_id: players(:john).id

    assert @fixture.reload.stats_verified
    assert_equal :verified, @fixture.stats_status
  end

  # ── PLAYS ─────────────────────────────────────────────────────────────────

  test "a play is a row per occurrence" do
    2.times { post_json plays_path, player_id: players(:john).id, kind: "dropped_bomb" }

    assert_equal 2, @fixture.plays.count
    assert_equal [ "dropped_bomb" ], @fixture.plays.pluck(:kind).uniq
  end

  test "plays stack, and both are true" do
    post_json plays_path, player_id: players(:john).id, kind: "dropped_bomb"
    post_json plays_path, player_id: players(:john).id, kind: "critical_error"

    assert_equal(-9, MatchLadder.new(@fixture, @team).played.find { |row| row.player == players(:john) }.points)
  end

  test "a play never touches verification" do
    post_json plays_path, player_id: players(:john).id, kind: "dropped_bomb"

    assert @fixture.reload.stats_verified, "TRL publishes nothing to check a Play against"
  end

  test "a kind the app does not record is refused" do
    post_json plays_path, player_id: players(:john).id, kind: "spilt_milk"

    assert_response :unprocessable_entity
    assert_equal 0, @fixture.plays.count
  end

  # ── THE SIDELINE ──────────────────────────────────────────────────────────

  test "the first write settles the squad" do
    assert_difference -> { @fixture.appearances.count }, @team.players.count do
      post_json touchdowns_path, scorer_player_id: players(:john).id
    end
  end

  test "sidelining somebody deletes their appearance" do
    post_json touchdowns_path, scorer_player_id: players(:john).id

    assert_difference -> { @fixture.appearances.count }, -1 do
      delete team_season_fixture_appearance_path(@team, @season, @fixture, players(:jane))
    end
  end

  test "bringing somebody back on writes it again" do
    post_json touchdowns_path, scorer_player_id: players(:john).id
    delete team_season_fixture_appearance_path(@team, @season, @fixture, players(:jane))

    assert_difference -> { @fixture.appearances.count }, 1 do
      post_json appearances_path, player_id: players(:jane).id
    end
  end

  test "somebody with stats in the game cannot be put on the sideline" do
    post_json touchdowns_path, scorer_player_id: players(:john).id

    delete team_season_fixture_appearance_path(@team, @season, @fixture, players(:john))

    assert_response :unprocessable_entity
    assert @fixture.appearances.exists?(player_id: players(:john).id)
  end

  # ── WHO MAY WRITE ─────────────────────────────────────────────────────────

  test "a stranger cannot enter stats" do
    sign_in_as users(:stranger)

    post_json touchdowns_path, scorer_player_id: players(:john).id

    assert_redirected_to team_path(@team)
    assert_equal 0, @fixture.touchdowns.count
  end

  test "a player from another team cannot be credited" do
    rivals = Team.create!(name: "Rivals", location: "Brisbane")
    outsider = rivals.players.create!(name: "Ringer")

    post_json touchdowns_path, scorer_player_id: outsider.id

    assert_response :not_found
    assert_equal 0, @fixture.touchdowns.count
  end
end
