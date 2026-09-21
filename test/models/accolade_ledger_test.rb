require "test_helper"

# Awarded as rows, never computed — and never revoked.
class AccoladeLedgerTest < ActiveSupport::TestCase
  setup do
    @user = users(:member_user)   # linked to Jane
    @jane = players(:jane)
    @fixture = fixtures(:played_no_stats)
  end

  def keys = @user.reload.accolade_awards.pluck(:key)

  # ── TIERED LADDERS ────────────────────────────────────────────────────────

  test "a rung is earned when the total crosses it" do
    AccoladeLedger.settle_totals(@user)
    assert_not_includes keys, "tries_5"

    5.times { @fixture.touchdowns.create!(scorer: @jane) }
    AccoladeLedger.settle_totals(@user)

    assert_includes keys, "tries_5"
    assert_not_includes keys, "tries_15"
  end

  test "settling twice does not award twice" do
    5.times { @fixture.touchdowns.create!(scorer: @jane) }
    2.times { AccoladeLedger.settle_totals(@user) }

    assert_equal 1, keys.count("tries_5")
  end

  # A corrected sheet must not silently take back an accolade somebody was
  # shown yesterday.
  test "a rung is never taken back when the total falls" do
    5.times { @fixture.touchdowns.create!(scorer: @jane) }
    AccoladeLedger.settle_totals(@user)

    @fixture.touchdowns.destroy_all
    AccoladeLedger.settle_totals(@user)

    assert_includes keys, "tries_5"
  end

  test "every rung below the total is earned at once, which is what claiming means" do
    25.times { @fixture.touchdowns.create!(scorer: @jane) }
    AccoladeLedger.settle_totals(@user)

    assert_includes keys, "tries_5"
    assert_includes keys, "tries_15"
    assert_includes keys, "tries_25"
  end

  # ── PER-GAME REPEATABLES ──────────────────────────────────────────────────

  test "MVP goes to the most points in the game, plays included" do
    @fixture.appearances.create!(player: @jane)
    @fixture.appearances.create!(player: players(:john))
    10.times { @fixture.plays.create!(player: @jane, kind: :bomb_catch) }
    @fixture.touchdowns.create!(scorer: players(:john))

    AccoladeLedger.settle_fixture(@fixture.reload)

    assert_includes keys, "mvp"
  end

  test "nobody is MVP of a game where nothing happened" do
    @fixture.open_sideline!

    AccoladeLedger.settle_fixture(@fixture.reload)

    assert_empty keys
  end

  test "a hat-trick is three tries in one game" do
    3.times { @fixture.touchdowns.create!(scorer: @jane) }

    AccoladeLedger.settle_fixture(@fixture.reload)

    assert_includes keys, "hat_trick"
  end

  # Scoped to one fixture's appearances, not the roster — which deletes the
  # changing-roster problem rather than solving it.
  test "a full house is everyone who took the field scoring" do
    @fixture.touchdowns.create!(scorer: @jane)
    AccoladeLedger.settle_fixture(@fixture.reload)
    assert_not_includes keys, "full_house", "one player is not a full house"

    @fixture.touchdowns.create!(scorer: players(:john))
    AccoladeLedger.settle_fixture(@fixture.reload)
    assert_includes keys, "full_house"
  end

  test "somebody who took the field and did not score breaks the full house" do
    @fixture.touchdowns.create!(scorer: @jane)
    @fixture.touchdowns.create!(scorer: players(:john))
    @fixture.appearances.create!(player: @team_late = teams(:warthogs).players.create!(name: "Late"))

    AccoladeLedger.settle_fixture(@fixture.reload)

    assert_not_includes keys, "full_house"
  end

  test "the same game cannot be won twice" do
    3.times { @fixture.touchdowns.create!(scorer: @jane) }
    2.times { AccoladeLedger.settle_fixture(@fixture.reload) }

    assert_equal 1, keys.count("hat_trick")
  end

  test "a repeatable happens again, and counts" do
    3.times { @fixture.touchdowns.create!(scorer: @jane) }
    AccoladeLedger.settle_fixture(@fixture.reload)

    other = fixtures(:played_with_stats)
    3.times { other.touchdowns.create!(scorer: @jane) }
    AccoladeLedger.settle_fixture(other.reload)

    assert_equal 2, keys.count("hat_trick")
  end

  # Fixing the finals cell shift is what makes this readable at all: before it,
  # every final was stored at midnight with the court name as the opponent.
  test "winning a grand final is an accolade, and losing one is not" do
    @fixture.update!(finals_label: "Grand Final")     # 10-2, a win
    @fixture.touchdowns.create!(scorer: @jane)
    AccoladeLedger.settle_fixture(@fixture.reload)
    assert_includes keys, "grand_final"

    lost = fixtures(:summer_final)
    lost.update!(finals_label: "Grand Final", our_score: 1, opponent_score: 9)
    AccoladeLedger.settle_fixture(lost.reload)
    assert_equal 1, keys.count("grand_final")
  end

  test "an ordinary game is not a grand final however it was won" do
    @fixture.touchdowns.create!(scorer: @jane)

    AccoladeLedger.settle_fixture(@fixture.reload)

    assert_not_includes keys, "grand_final"
  end

  test "the Clive Churchill Medal goes to the MVP of a won grand final" do
    @fixture.update!(finals_label: "Grand Final")     # 10-2, a win
    @fixture.appearances.create!(player: players(:john))
    10.times { @fixture.plays.create!(player: @jane, kind: :bomb_catch) }

    AccoladeLedger.settle_fixture(@fixture.reload)

    assert_includes keys, "clive_churchill"
  end

  test "the MVP of an ordinary win is not awarded the Clive Churchill Medal" do
    @fixture.touchdowns.create!(scorer: @jane)

    AccoladeLedger.settle_fixture(@fixture.reload)

    assert_not_includes keys, "clive_churchill"
  end

  test "losing a grand final does not earn the MVP a Clive Churchill Medal" do
    lost = fixtures(:summer_final)
    lost.update!(finals_label: "Grand Final", our_score: 1, opponent_score: 9)
    lost.plays.create!(player: @jane, kind: :bomb_catch)

    AccoladeLedger.settle_fixture(lost.reload)

    assert_not_includes keys, "clive_churchill"
  end

  # ── PER-SEASON REPEATABLES ────────────────────────────────────────────────

  test "an undefeated season needs every game played and none of them lost" do
    season = seasons(:winter_2026)
    season.fixtures.update_all(our_score: 5, opponent_score: 1)
    @fixture.appearances.create!(player: @jane)

    AccoladeLedger.settle_season(season.reload)

    assert_includes keys, "undefeated_season"
  end

  test "one loss is not an undefeated season" do
    season = seasons(:winter_2026)
    season.fixtures.update_all(our_score: 5, opponent_score: 1)
    season.fixtures.first.update!(our_score: 1, opponent_score: 5)
    @fixture.appearances.create!(player: @jane)

    AccoladeLedger.settle_season(season.reload)

    assert_not_includes keys, "undefeated_season"
  end

  test "a season still being played is not undefeated yet" do
    season = seasons(:winter_2026)   # holds an upcoming fixture with no score
    @fixture.appearances.create!(player: @jane)

    AccoladeLedger.settle_season(season.reload)

    assert_not_includes keys, "undefeated_season"
  end

  test "finishing top of the division is read off the ladder TRL publishes" do
    season = seasons(:winter_2026)
    season.update!(ladder_position: 1, ladder_size: 6)
    @fixture.appearances.create!(player: @jane)

    AccoladeLedger.settle_season(season.reload)

    assert_includes keys, "top_of_the_ladder"
  end

  test "second is not top" do
    season = seasons(:winter_2026)
    season.update!(ladder_position: 2, ladder_size: 6)
    @fixture.appearances.create!(player: @jane)

    AccoladeLedger.settle_season(season.reload)

    assert_not_includes keys, "top_of_the_ladder"
  end

  # ── WHO EARNS ─────────────────────────────────────────────────────────────

  test "an unclaimed roster entry earns nothing until somebody claims it" do
    5.times { @fixture.touchdowns.create!(scorer: players(:john)) }   # John has no account

    AccoladeLedger.settle_fixture(@fixture.reload)

    assert_equal 0, AccoladeAward.where(key: "hat_trick").count
  end
end
