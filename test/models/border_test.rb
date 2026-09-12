require "test_helper"

class BorderTest < ActiveSupport::TestCase
  # Twelve tiers from four pieces of art, spanning one game to about three
  # hundred. Colour alone runs out after about four distinguishable steps,
  # which is why the shape climbs too.
  test "four shapes and three metals make twelve tiers" do
    assert_equal 12, Border::LADDER.size
    assert_equal %w[circle shield octagon star], Border::LADDER.map(&:shape).uniq
    assert_equal %w[bronze silver gold], Border::LADDER.map(&:metal).uniq
  end

  test "the ladder only ever climbs" do
    levels = Border::LADDER.map(&:level)
    assert_equal levels.sort, levels
  end

  test "a border is the highest tier reached, never a choice" do
    assert_equal "bronze circle", Border.for(1).name
    assert_equal "bronze circle", Border.for(2).name   # 3 is the next rung
    assert_equal "gold circle", Border.for(6).name
    assert_equal "bronze shield", Border.for(10).name
    assert_equal "gold star", Border.for(99).name
  end

  test "there is no border before there is a level" do
    assert_nil Border.for(0)
  end

  test "the next tier is what there is to climb to" do
    assert_equal 3, Border.next_after(1).level
    assert_nil Border.next_after(58), "the top of the ladder has nothing above it"
  end
end
