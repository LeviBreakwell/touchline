require "test_helper"

class LevelTest < ActiveSupport::TestCase
  test "each level costs two XP more than the last" do
    assert_equal 10, Level.cost_of(1)
    assert_equal 12, Level.cost_of(2)
    assert_equal 30, Level.cost_of(11)
  end

  test "the cumulative cost of level L is L(L + 9)" do
    (1..40).each { |level| assert_equal level * (level + 9), Level.xp_for(level) }
  end

  # The curve is quoted in games, never in seasons: a season is anywhere from
  # about five games to about twenty-six depending on how many teams are in the
  # competition, so a milestone quoted in seasons means something different in
  # every league. A game is worth about 12.5 XP.
  test "the curve lands where the economy says it does" do
    { 1 => 1, 4 => 4, 10 => 15, 20 => 46, 30 => 94, 40 => 157 }.each do |level, games|
      assert_in_delta games, Level.xp_for(level) / 12.5, 1.5,
        "level #{level} should be about #{games} games of merely turning up"
    end
  end

  test "level is the inverse of the cost to reach it" do
    (0..40).each { |level| assert_equal level, Level.for(Level.xp_for(level)) }
  end

  test "XP part way through a level does not round up to it" do
    assert_equal 4, Level.for(Level.xp_for(5) - 1)
  end

  test "nobody is level 1 until they have played" do
    assert_equal 0, Level.for(0)
    assert_equal 0, Level.for(9)
    assert_equal 1, Level.for(10)
  end

  test "progress is how far into the current level, and how far it is across" do
    assert_equal [ 0, 12 ], Level.progress(Level.xp_for(1))
    assert_equal [ 3, 12 ], Level.progress(Level.xp_for(1) + 3)
  end
end
