require "test_helper"

# John: 8 tries, 5 assists, 3 games across two seasons, on the Warthogs.
class CareerTest < ActiveSupport::TestCase
  setup { @career = Career.new(players(:john)) }

  test "the totals are the Player's, over every season they played" do
    assert_equal 8, @career.line.tries
    assert_equal 5, @career.line.assists
    assert_equal 3, @career.line.games
    assert_predicate @career, :any?
  end

  # This season leads on the page, so it has to be the season they actually
  # played most recently — not whichever row the database hands back first.
  test "this season is the most recent one they appeared in" do
    assert_equal seasons(:winter_2026), @career.season
    assert_equal [ seasons(:winter_2026), seasons(:summer_2025) ], @career.seasons
    assert_equal @career.season_line.games, players(:john).season_stats(seasons(:winter_2026)).games
  end

  test "form compares this season against the whole career" do
    assert_equal @career.form.on(:tries).direction,
                 Form.new(season: @career.season_line, career: @career.line).on(:tries).direction
  end

  # A roster entry nobody has taken the field as still answers every question,
  # rather than the page having to guard each one.
  test "a player who has never played answers with empty rather than nil" do
    career = Career.new(teams(:warthogs).players.create!(name: "Newcomer"))

    assert_not career.any?
    assert_equal 0, career.line.games
    assert_nil career.season
    assert_equal 0, career.season_line.games
    assert_empty career.seasons
  end

  # A Season belongs to a Team, which is why a career is team-scoped and an
  # account is not: two rosters is two careers and still one account.
  test "a career covers one team, never the account behind it" do
    elsewhere = Team.create!(name: "Magpies", location: "Ipswich")
    other = elsewhere.players.create!(name: "John Elsewhere", user: players(:john).user)

    assert_equal teams(:warthogs), @career.team
    assert_equal 0, Career.new(other).line.games
  end
end
