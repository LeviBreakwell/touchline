require "test_helper"

# The indicator compares somebody against themselves, because nothing else has
# data: a Team is thirteen people, so a percentile is worth 7.7 points a rank,
# and "competition" and "app-wide" have no source at all.
class FormTest < ActiveSupport::TestCase
  def line(games:, tries: 0, assists: 0, plays: {})
    StatLine.new(games: games, tries: tries, assists: assists, plays: plays)
  end

  def reading(stat, season:, career:)
    Form.new(season: season, career: career).on(stat)
  end

  test "a better season than the career reads as up" do
    up = reading(:tries, season: line(games: 5, tries: 10), career: line(games: 20, tries: 20))

    assert_equal :up, up.direction
    assert up.good?
    assert up.certain?
  end

  test "a worse season reads as down" do
    down = reading(:tries, season: line(games: 5, tries: 1), career: line(games: 20, tries: 20))

    assert_equal :down, down.direction
    assert_not down.good?
  end

  # A season one try better over ten games is not a trend.
  test "a small change is holding form, not a trend" do
    steady = reading(:tries, season: line(games: 10, tries: 11), career: line(games: 100, tries: 105))

    assert steady.level?
    assert_not steady.good?, "level is neither good nor bad"
  end

  # Up is not good for everything. A rising drop count is a falling player.
  test "the same arrow means opposite things on opposite stats" do
    more_catches = reading(:bomb_catches,
      season: line(games: 5, plays: { "bomb_catch" => 20 }),
      career: line(games: 20, plays: { "bomb_catch" => 20 }))
    more_drops = reading(:dropped_bombs,
      season: line(games: 5, plays: { "dropped_bomb" => 20 }),
      career: line(games: 20, plays: { "dropped_bomb" => 20 }))

    assert_equal :up, more_catches.direction
    assert_equal :up, more_drops.direction
    assert more_catches.good?
    assert_not more_drops.good?
  end

  # An absent arrow reads as "level", so "we can't tell" needs its own marker.
  test "too few games either side is not an answer" do
    thin_season = reading(:tries, season: line(games: 2, tries: 8), career: line(games: 20, tries: 20))
    thin_career = reading(:tries, season: line(games: 5, tries: 8), career: line(games: 2, tries: 2))

    assert_not thin_season.certain?
    assert_not thin_career.certain?
  end

  test "a catch rate is compared as the rate it already is" do
    better = reading(:catch_rate,
      season: line(games: 5, plays: { "bomb_catch" => 9, "dropped_bomb" => 1 }),
      career: line(games: 20, plays: { "bomb_catch" => 10, "dropped_bomb" => 10 }))

    assert_equal :up, better.direction
  end

  test "nothing either way is level rather than a division by zero" do
    nothing = reading(:tries, season: line(games: 5), career: line(games: 20))

    assert nothing.level?
  end

  test "the first of anything is up, not an error" do
    first = reading(:tries, season: line(games: 5, tries: 3), career: line(games: 20))

    assert_equal :up, first.direction
  end
end
