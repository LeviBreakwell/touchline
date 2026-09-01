require "test_helper"

class StatSheetTest < ActiveSupport::TestCase
  setup do
    @john = players(:john)
    @jane = players(:jane)
  end

  def sheet(fixture, rows)
    StatSheet.new(fixture, rows)
  end

  def row(player, tries: 0, assists: 0, played: "1")
    { player_id: player.id, tries: tries, assists: assists, played: played }
  end

  # ── INSIDE TRL'S SCORE ────────────────────────────────────────────────────

  test "a sheet that fits TRL's score saves" do
    fixture = fixtures(:played_no_stats)   # TRL: 10 tries

    assert sheet(fixture, [ row(@john, tries: 6, assists: 4), row(@jane, tries: 4, assists: 6) ]).save
    assert_equal 10, fixture.entered_tries
    assert fixture.reload.stats_verified
  end

  test "a sheet that lands exactly on TRL's score saves" do
    fixture = fixtures(:played_no_stats)   # TRL: 10 tries

    assert sheet(fixture, [ row(@john, tries: 10, assists: 10) ]).save
  end

  # ── OVER TRL'S SCORE ──────────────────────────────────────────────────────

  test "more tries than TRL published is refused" do
    fixture = fixtures(:played_no_stats)   # TRL: 10 tries
    s = sheet(fixture, [ row(@john, tries: 7), row(@jane, tries: 4) ])

    assert_not s.save
    assert_equal 0, fixture.game_stats.count
    assert_match(/10 tries/, s.error)
    assert_match(/take 1 off/i, s.error)
  end

  test "more assists than TRL published tries is refused" do
    fixture = fixtures(:played_no_stats)   # TRL: 10 tries
    s = sheet(fixture, [ row(@john, tries: 5, assists: 8), row(@jane, tries: 5, assists: 8) ])

    assert_not s.save
    assert_match(/assist/i, s.error)
  end

  test "a refused sheet nothing saves, not even the rows that fit" do
    fixture = fixtures(:played_no_stats)

    assert_not sheet(fixture, [ row(@john, tries: 1), row(@jane, tries: 99) ]).save
    assert_equal 0, fixture.game_stats.count
  end

  test "a refused sheet keeps the Member's numbers for re-rendering" do
    fixture = fixtures(:played_no_stats)
    s = sheet(fixture, [ row(@john, tries: 99) ])

    assert_not s.save
    assert_equal 99, s.stats[@john.id].tries
  end

  test "a Player left off the sheet still counts against TRL's ceiling" do
    fixture = fixtures(:played_with_stats)   # TRL: 5 tries, John already has 3
    s = sheet(fixture, [ row(@jane, tries: 3) ])

    assert_not s.save
  end

  # ── EARLY ENTRY ───────────────────────────────────────────────────────────

  test "any number saves before TRL publishes a result" do
    fixture = fixtures(:upcoming)

    assert sheet(fixture, [ row(@john, tries: 40, assists: 40) ]).save
    assert_not fixture.reload.stats_verified
  end

  # ── MOVING STATS AROUND ───────────────────────────────────────────────────

  test "handing a try from one player to another does not trip the ceiling" do
    fixture = fixtures(:played_with_stats)   # TRL: 5. John 3T 1A, Jane 0

    assert sheet(fixture, [ row(@jane, tries: 3, assists: 1), row(@john) ]).save
    assert_equal 3, fixture.game_stats.find_by(player: @jane).tries
    assert_equal 0, fixture.game_stats.find_by(player: @john).tries
  end

  test "swapping tries for assists between players does not trip the ceiling" do
    fixture = fixtures(:played_with_stats)   # TRL: 5
    assert sheet(fixture, [ row(@john, tries: 5), row(@jane, assists: 5) ]).save

    # Now hand each player the other's column — every field stays at 5 overall.
    assert sheet(fixture, [ row(@john, assists: 5), row(@jane, tries: 5) ]).save
    assert_equal 5, fixture.game_stats.find_by(player: @jane).tries
    assert_equal 5, fixture.game_stats.find_by(player: @john).assists
  end

  # ── VERIFICATION SIDE EFFECTS ─────────────────────────────────────────────

  test "saving a sheet that no longer fits an amended result marks it over" do
    fixture = fixtures(:played_with_stats)
    fixture.update_columns(our_score: nil, opponent_score: nil)

    assert sheet(fixture, [ row(@john, tries: 9) ]).save

    fixture.update!(our_score: 4, opponent_score: 2)
    fixture.refresh_stats_verification!
    assert_equal :over_official, fixture.stats_status
  end

  test "an absent player carries no stats onto the sheet" do
    fixture = fixtures(:played_no_stats)
    assert sheet(fixture, [ row(@john, tries: 0, assists: 0, played: "0") ]).save

    assert_not fixture.game_stats.find_by(player: @john).played
  end
end
