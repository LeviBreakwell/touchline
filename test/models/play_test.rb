require "test_helper"

class PlayTest < ActiveSupport::TestCase
  setup { @fixture = fixtures(:played_no_stats) }

  test "the starter set is worth what #16 settled on" do
    assert_equal 1,  Play.new(kind: :bomb_catch).points
    assert_equal(-1, Play.new(kind: :dropped_bomb).points)
    assert_equal(-2, Play.new(kind: :opposition_assist).points)
  end

  test "a play the app does not record cannot be written" do
    assert_raises(ArgumentError) { @fixture.plays.create!(player: players(:john), kind: "spilt_milk") }
  end

  test "a row per occurrence, so undoing one is deleting it" do
    3.times { @fixture.plays.create!(player: players(:john), kind: :bomb_catch) }
    @fixture.plays.first.destroy!

    assert_equal 2, @fixture.plays.count
  end

  test "recording a play records that the player took the field" do
    @fixture.plays.create!(player: players(:john), kind: :dropped_bomb)

    assert @fixture.appearances.exists?(player_id: players(:john).id)
  end

  # TRL publishes nothing to check a Play against, and a ceiling only ever
  # bounds over-reporting — nobody games a board by adding penalties to
  # themselves.
  test "a play never moves verification" do
    assert @fixture.reload.stats_verified

    @fixture.plays.create!(player: players(:john), kind: :opposition_assist)

    assert @fixture.reload.stats_verified
  end
end
