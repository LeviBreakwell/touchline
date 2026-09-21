require "test_helper"

class FixturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team    = teams(:warthogs)
    @season  = seasons(:winter_2026)
    @fixture = fixtures(:played_with_stats)
    sign_in_as users(:member_user)
  end

  test "show is publicly accessible" do
    delete session_path
    get team_season_fixture_path(@team, @season, @fixture)
    assert_response :success
  end

  test "a member gets a ladder that takes gestures" do
    get team_season_fixture_path(@team, @season, @fixture)

    assert_response :success
    assert_select "[data-controller~=match-ladder]"
    assert_select ".ladder--editable"
  end

  test "a visitor gets the same ladder without the gestures" do
    delete session_path
    get team_season_fixture_path(@team, @season, @fixture)

    assert_response :success
    assert_select ".ladder"
    assert_select "[data-controller~=match-ladder]", count: 0
    assert_select ".ladder--editable", count: 0
  end

  test "a card carries the tallies and the points" do
    get team_season_fixture_path(@team, @season, @fixture)

    # John: 3 tries, 1 assist, no plays — 28 points
    assert_select ".lcard[data-player-id=?]", players(:john).id.to_s do
      assert_select ".lchip.t", text: "3"
      assert_select ".lchip.a", text: "1"
      assert_select ".lcard-pts", text: /\+28/
    end
  end

  test "the player with the most points wears the crown" do
    get team_season_fixture_path(@team, @season, @fixture)

    assert_select ".lcard.mvp[data-player-id=?]", players(:john).id.to_s
    assert_select ".lcard-crown", 1
  end

  test "a player with no appearance is on the sideline" do
    get team_season_fixture_path(@team, @season, @fixture)

    assert_select ".ladder-sideline"
    assert_select ".lcard.sidelined[data-player-id=?]", players(:jane).id.to_s
  end

  test "everyone defaults to played on a fixture nobody has touched" do
    get team_season_fixture_path(@team, @season, fixtures(:played_no_stats))

    assert_select ".lcard.sidelined", count: 0
    assert_select ".lcard", @team.players.count
  end

  test "an unclaimed roster entry carries no cosmetics and says so" do
    get team_season_fixture_path(@team, @season, @fixture)

    # John has no user account behind him
    assert_select ".lcard.unclaimed[data-player-id=?]", players(:john).id.to_s do
      assert_select ".lcard-title", text: /Roster only/
    end
  end

  test "a finals fixture names the round it was" do
    @fixture.update!(finals_label: "Grand Final")
    get team_season_fixture_path(@team, @season, @fixture)

    assert_select ".card-meta", text: /Grand Final/
  end
end
