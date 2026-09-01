require "test_helper"

class FixtureTest < ActiveSupport::TestCase
  test "played? is true when both scores present" do
    f = fixtures(:played_with_stats)
    assert f.played?
  end

  test "played? is false when scores are missing" do
    f = fixtures(:upcoming)
    assert_not f.played?
  end

  test "result is win when our score is higher" do
    f = fixtures(:played_with_stats)   # 5-3
    assert_equal "win", f.result
  end

  test "result is loss when our score is lower" do
    f = fixtures(:played_no_stats)     # 10-2 … wait, that's a win
    # build an inline loss
    f2 = Fixture.new(our_score: 2, opponent_score: 5)
    assert_equal "loss", f2.result
  end

  test "result is draw when scores are equal" do
    f = Fixture.new(our_score: 3, opponent_score: 3)
    assert_equal "draw", f.result
  end

  test "result is nil when not played" do
    f = fixtures(:upcoming)
    assert_nil f.result
  end

  # ── TRL VERIFICATION ──────────────────────────────────────────────────────

  test "official_tries is the score TRL published" do
    assert_equal 5, fixtures(:played_with_stats).official_tries
    assert_nil fixtures(:awaiting_trl).official_tries
  end

  test "a sheet inside TRL's score is verified" do
    f = fixtures(:played_with_stats)   # 5 tries published, 3 entered

    assert f.refresh_stats_verification!
    assert_equal :verified, f.stats_status
  end

  test "a sheet entered before TRL published is awaiting the result" do
    f = fixtures(:awaiting_trl)

    assert_not f.refresh_stats_verification!
    assert_equal :awaiting_result, f.stats_status
  end

  test "a result landing lower than the sheet takes verification away" do
    f = fixtures(:played_with_stats)   # 3 tries entered
    f.update!(our_score: 2, opponent_score: 1)
    f.refresh_stats_verification!

    assert_not f.stats_verified
    assert_equal :over_official, f.stats_status
  end

  test "a result landing confirms a sheet entered before it" do
    f = fixtures(:awaiting_trl)        # 4 tries, 2 assists entered early
    f.update!(our_score: 4, opponent_score: 3)

    assert f.refresh_stats_verification!
    assert_equal :verified, f.stats_status
  end

  test "assists are capped by the published try count too" do
    f = fixtures(:awaiting_trl)        # 4 tries, 2 assists entered early
    f.update!(our_score: 1, opponent_score: 0)

    assert_not f.refresh_stats_verification!
  end

  test "verified scope returns only fixtures squared against TRL" do
    assert_includes Fixture.verified, fixtures(:played_with_stats)
    assert_not_includes Fixture.verified, fixtures(:awaiting_trl)
  end
end
