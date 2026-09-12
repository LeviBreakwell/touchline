require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  def glyph_count(html) = Nokogiri::HTML.fragment(html.to_s).css("svg").size

  test "renders one glyph per try and per assist" do
    assert_equal 3, glyph_count(stat_tally(3, :tries))
    assert_equal 1, glyph_count(stat_tally(1, :assists))
  end

  test "renders nothing at zero so a card gains no empty row" do
    assert_nil stat_tally(0, :tries)
    assert_nil stat_tally(nil, :assists)
  end

  test "renders a full run of glyphs up to the cap" do
    assert_equal ApplicationHelper::TALLY_CAP,
      glyph_count(stat_tally(ApplicationHelper::TALLY_CAP, :tries))
  end

  test "collapses to a count past the cap rather than wrapping the card" do
    over = ApplicationHelper::TALLY_CAP + 1
    html = stat_tally(over, :tries)

    assert_equal 1, glyph_count(html)
    assert_includes html, "×#{over}"
  end

  test "spells the tally out for screen readers" do
    assert_includes stat_tally(1, :tries), %(aria-label="1 try")
    assert_includes stat_tally(3, :tries), %(aria-label="3 tries")
    assert_includes stat_tally(2, :assists), %(aria-label="2 assists")
  end

  def roster = teams(:warthogs).players.index_by(&:id)

  test "fixture_scorers leaves off a player who put nothing on the board" do
    # Jane was named for this fixture and did not take the field
    assert_equal [ players(:john) ], fixture_scorers(fixtures(:played_with_stats), roster).map(&:player)
  end

  test "fixture_scorers puts the biggest contribution first" do
    fixture = fixtures(:awaiting_trl) # john has 4 tries, 2 assists here
    fixture.appearances.create!(player: players(:jane))
    9.times { fixture.touchdowns.create!(scorer: players(:jane)) }

    assert_equal [ players(:jane), players(:john) ], fixture_scorers(fixture.reload, roster).map(&:player)
  end

  test "fixture_scorers counts an imported assist under its assister and nobody else" do
    fixture = fixtures(:played_with_stats) # john: 3 tries, 1 scorer-less assist

    scorer = fixture_scorers(fixture, roster).sole

    assert_equal 3, scorer.tries
    assert_equal 1, scorer.assists
  end

  # ── LEADERBOARD MOVEMENT & STREAK ─────────────────────────────────────────

  def board_row(movement: nil, streak: 0)
    Leaderboard::Row.new(player: players(:john), tries: 0, assists: 0, games: 1,
                         movement: movement, streak: streak)
  end

  test "a climb renders an up arrow and the places gained" do
    html = rank_movement(board_row(movement: 2))

    assert_includes html, "move-up"
    assert_includes html, %(aria-label="Up 2")
  end

  test "a fall renders a down arrow and the places lost" do
    html = rank_movement(board_row(movement: -3))

    assert_includes html, "move-down"
    assert_includes html, %(aria-label="Down 3")
  end

  test "holding a position renders a dash rather than an arrow" do
    html = rank_movement(board_row(movement: 0))

    assert_includes html, "–"
    assert_includes html, %(title="No change")
    assert_not_includes html, "move-up"
    assert_not_includes html, "move-down"
  end

  test "a player with no previous position renders a dash, distinguished on hover" do
    html = rank_movement(board_row(movement: nil))

    assert_includes html, "–"
    assert_includes html, %(title="First game on this board")
  end

  test "the flame appears only once the run reaches the threshold" do
    assert_nil hot_streak_flame(board_row(streak: Leaderboard::HOT_STREAK - 1))
    assert_includes hot_streak_flame(board_row(streak: Leaderboard::HOT_STREAK)), "flame"
  end

  test "the flame names the run length for screen readers" do
    assert_includes hot_streak_flame(board_row(streak: 5)), %(aria-label="Scored in 5 straight games")
  end
end
