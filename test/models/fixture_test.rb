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
end
