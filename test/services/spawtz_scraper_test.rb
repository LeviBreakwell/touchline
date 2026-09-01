require "test_helper"
require "minitest/mock"
require "open-uri" # up front: SpawtzScraper's own require would otherwise replace the URI.open stub mid-test

class SpawtzScraperTest < ActiveSupport::TestCase
  setup do
    @team = teams(:warthogs)
    @team.update!(spawtz_season_id: "1500001", trl_location_slug: nil)
    @season = @team.seasons.create!(name: "Bardon Mondays - 2026 Spring", spawtz_season_id: "1500001")
  end

  # Spawtz's real TeamProfile layout: Date | Time | Court | Opposition | Result,
  # with the header row in <th> so it never reaches the cell parser.
  def draw_html(rows)
    body = rows.map { |date, time, opponent, result|
      "<tr><td>#{date}</td><td>#{time}</td><td>Field 1</td><td>#{opponent}</td><td>#{result}</td></tr>"
    }.join
    <<~HTML
      <html><body><table>
        <tr><th>Date</th><th>Time</th><th>Court</th><th>Opposition</th><th>Result</th></tr>
        #{body}
      </table></body></html>
    HTML
  end

  def sync(rows)
    URI.stub(:open, draw_html(rows)) do
      SpawtzScraper.new(@team).sync_fixtures
    end
  end

  def fixture_at(time_string)
    @season.fixtures.reload.find_by(date: Time.zone.parse(time_string))
  end

  test "builds the season's fixtures from the published draw" do
    sync([
      [ "Mon 27 Jul 2026", "8:25PM", "Le Mans", "5 - 4" ],
      [ "Mon 03 Aug 2026", "6:55PM", "Just The Lads", "(not played)" ]
    ])

    assert_equal 2, @season.fixtures.count
    le_mans = fixture_at("27 Jul 2026 8:25PM")
    assert_equal "Le Mans", le_mans.opponent_name
    assert_equal [ 5, 4 ], [ le_mans.our_score, le_mans.opponent_score ]
    assert_nil fixture_at("03 Aug 2026 6:55PM").our_score
  end

  test "a rescheduled kickoff updates the fixture in place rather than duplicating it" do
    sync([ [ "Mon 31 Aug 2026", "8:25PM", "Le Mans", "(not played)" ] ])
    original = @season.fixtures.sole

    sync([ [ "Mon 31 Aug 2026", "8:15PM", "Le Mans", "8 - 2" ] ])

    assert_equal 1, @season.fixtures.reload.count, "a reschedule must not strand a second fixture that day"
    original.reload
    assert_equal Time.zone.parse("31 Aug 2026 8:15PM"), original.date
    assert_equal 8, original.our_score
  end

  test "a round rebuilt with a different opponent leaves no ghost behind" do
    sync([ [ "Mon 24 Aug 2026", "7:40PM", "The Long Johns", "(not played)" ] ])

    sync([ [ "Mon 24 Aug 2026", "8:15PM", "Da Boiiis", "11 - 1" ] ])

    assert_equal [ "Da Boiiis" ], @season.fixtures.reload.pluck(:opponent_name)
  end

  test "a fixture dropped from the draw is pruned" do
    sync([
      [ "Mon 24 Aug 2026", "8:15PM", "Da Boiiis", "(not played)" ],
      [ "Mon 31 Aug 2026", "8:15PM", "Le Mans", "(not played)" ]
    ])
    assert_equal 2, @season.fixtures.count

    sync([ [ "Mon 31 Aug 2026", "8:15PM", "Le Mans", "(not played)" ] ])

    assert_equal [ "Le Mans" ], @season.fixtures.reload.pluck(:opponent_name)
  end

  test "a stranded fixture holding a stat sheet is kept for a human to resolve" do
    sync([ [ "Mon 24 Aug 2026", "7:40PM", "The Long Johns", "(not played)" ] ])
    stranded = @season.fixtures.sole
    stranded.game_stats.create!(player: players(:john), tries: 2, assists: 1)

    sync([ [ "Mon 31 Aug 2026", "8:15PM", "Le Mans", "(not played)" ] ])

    assert Fixture.exists?(stranded.id), "pruning must never destroy entered stats"
    assert_equal 2, @season.fixtures.reload.count
  end

  test "a stranded fixture holding a published score is kept" do
    sync([ [ "Mon 24 Aug 2026", "7:40PM", "The Long Johns", "6 - 0" ] ])

    sync([ [ "Mon 31 Aug 2026", "8:15PM", "Le Mans", "(not played)" ] ])

    assert_equal 2, @season.fixtures.reload.count
  end

  test "a scrape that parses no rows prunes nothing" do
    sync([ [ "Mon 31 Aug 2026", "8:15PM", "Le Mans", "(not played)" ] ])

    URI.stub(:open, "<html><body><p>Season not found</p></body></html>") do
      SpawtzScraper.new(@team).sync_fixtures
    end

    assert_equal 1, @season.fixtures.reload.count,
      "an unparseable page must not read as TRL cancelling the season"
  end

  test "a double-header keeps both games when every kickoff moves" do
    sync([
      [ "Mon 07 Sep 2026", "6:45PM", "Just The Lads", "(not played)" ],
      [ "Mon 07 Sep 2026", "8:15PM", "Just The Lads", "(not played)" ]
    ])
    assert_equal 2, @season.fixtures.count

    sync([
      [ "Mon 07 Sep 2026", "7:00PM", "Just The Lads", "3 - 1" ],
      [ "Mon 07 Sep 2026", "8:30PM", "Just The Lads", "2 - 5" ]
    ])

    assert_equal 2, @season.fixtures.reload.count
    assert_equal [ 3, 2 ], @season.fixtures.order(:date).pluck(:our_score)
  end
end
