require "test_helper"

class TouchdownTest < ActiveSupport::TestCase
  setup do
    @fixture = fixtures(:played_no_stats)
  end

  test "a try can stand without an assist" do
    assert @fixture.touchdowns.create!(scorer: players(:john)).valid?
  end

  test "an assist is a column on the try it produced" do
    touchdown = @fixture.touchdowns.create!(scorer: players(:john), assister: players(:jane))

    assert_equal players(:jane), touchdown.assister
    assert_equal 1, @fixture.entered_assists
  end

  # Not a validation anywhere: a try holds one assister column, so there is no
  # shape in which a second assist could be recorded.
  test "assists cannot outnumber tries" do
    3.times { @fixture.touchdowns.create!(scorer: players(:john), assister: players(:jane)) }

    assert_operator @fixture.entered_assists, :<=, @fixture.entered_tries
  end

  test "a row has to name somebody" do
    assert_not @fixture.touchdowns.new.valid?
  end

  test "nobody assists their own try" do
    touchdown = @fixture.touchdowns.new(scorer: players(:john), assister: players(:john))

    assert_not touchdown.valid?
  end

  # ── IMPORTED HISTORY ──────────────────────────────────────────────────────

  test "a scorer-less row is an imported assist and counts towards no try tally" do
    fixture = fixtures(:played_with_stats)   # 3 tries and one imported assist

    assert_equal 3, fixture.entered_tries
    assert_equal 1, fixture.entered_assists
    assert_equal 3, players(:john).career_stats.tries - 5   # 8 career tries, 5 elsewhere
  end

  # ── APPEARANCES AND VERIFICATION ──────────────────────────────────────────

  test "recording a try records that both players took the field" do
    @fixture.touchdowns.create!(scorer: players(:john), assister: players(:jane))

    assert @fixture.appearances.exists?(player_id: players(:john).id)
    assert @fixture.appearances.exists?(player_id: players(:jane).id)
  end

  test "writing a try re-measures the fixture against TRL" do
    fixture = fixtures(:awaiting_trl)
    fixture.update!(our_score: 4, opponent_score: 3)   # 4 tries already entered
    fixture.refresh_stats_verification!
    assert fixture.stats_verified

    fixture.touchdowns.create!(scorer: players(:john))

    assert_not fixture.reload.stats_verified
  end

  test "deleting a try re-measures it too" do
    fixture = fixtures(:played_with_stats)
    fixture.update!(our_score: 2, opponent_score: 1)   # 3 entered, TRL says 2
    fixture.refresh_stats_verification!
    assert_not fixture.stats_verified

    fixture.touchdowns.scored.first.destroy!

    assert fixture.reload.stats_verified
  end
end
