require "test_helper"

# The entry screen is a live standing, so the ladder is what the tests are
# about: the order, the crown, and who is on the grass.
class MatchLadderTest < ActiveSupport::TestCase
  setup do
    @team = teams(:warthogs)
    @fixture = fixtures(:played_no_stats)
  end

  def ladder = MatchLadder.new(@fixture.reload, @team)
  def row_for(player) = ladder.played.find { |row| row.player == player }

  test "everyone defaults to played until somebody writes to the fixture" do
    assert_equal @team.players.count, ladder.played.size
    assert_empty ladder.sidelined
  end

  test "once the squad is settled the rows are the record" do
    @fixture.open_sideline!
    @fixture.appearances.find_by(player_id: players(:jane).id).destroy!

    assert_equal [ players(:jane) ], ladder.sidelined.map(&:player)
    assert_equal [ players(:john) ], ladder.played.map(&:player)
  end

  test "the ladder is ordered by points" do
    @fixture.touchdowns.create!(scorer: players(:jane), assister: players(:john))

    assert_equal [ players(:jane), players(:john) ], ladder.played.map(&:player)
  end

  test "a play can put somebody below a player who did nothing" do
    @fixture.open_sideline!
    @fixture.plays.create!(player: players(:john), kind: :critical_error)

    assert_equal [ players(:jane), players(:john) ], ladder.played.map(&:player)
    assert_equal(-8, row_for(players(:john)).points)
  end

  test "both negatives are collapsed into one column, and they stack" do
    @fixture.plays.create!(player: players(:john), kind: :dropped_bomb)
    @fixture.plays.create!(player: players(:john), kind: :critical_error)

    row = row_for(players(:john))
    assert_equal 2, row.negative_plays
    assert_equal(-9, row.points)
  end

  test "MVP is the most points in the game, plays included" do
    @fixture.touchdowns.create!(scorer: players(:john))
    10.times { @fixture.plays.create!(player: players(:jane), kind: :bomb_catch) }

    assert_equal players(:jane), ladder.mvp.player
  end

  test "nobody is MVP of a game where nothing happened" do
    @fixture.open_sideline!

    assert_nil ladder.mvp
  end

  test "connections carry how often a pair have combined" do
    2.times { @fixture.touchdowns.create!(scorer: players(:john), assister: players(:jane)) }

    connection = ladder.connections.sole
    assert_equal [ players(:jane).id, players(:john).id, 2 ],
                 [ connection.assister_id, connection.scorer_id, connection.count ]
  end

  test "an imported assist draws no arc, because there is no try to draw it to" do
    @fixture.touchdowns.create!(assister: players(:jane))

    assert_empty ladder.connections
  end
end
