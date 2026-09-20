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

  # A finals row is the same five cells with the round's name pushed in front
  # of them: six cells where an ordinary row has five.
  def finals_html(rows)
    body = rows.map { |label, date, time, opponent, result|
      "<tr><td>#{label}</td><td>#{date}</td><td>#{time}</td><td>Field 1</td><td>#{opponent}</td><td>#{result}</td></tr>"
    }.join
    "<html><body><table>#{body}</table></body></html>"
  end

  def sync(rows)
    URI.stub(:open, draw_html(rows)) do
      SpawtzScraper.new(@team).sync_fixtures
    end
  end

  def sync_html(html)
    URI.stub(:open, html) do
      SpawtzScraper.new(@team).sync_fixtures
    end
  end

  # Spawtz publishes one standings table per division, each under an <h3> that
  # names it, and every team in it links back to itself carrying the division
  # it plays in. The cell in front of the team holds a tie-break tooltip whose
  # links have no href, which is why it is here.
  def standings_html(*divisions)
    body = divisions.map { |name, division_id, teams|
      rows = teams.map { |team_name, team_id|
        %(<tr><td><a>1</a>Position assignment decided via points</td>) +
        %(<td class="STTeamCell"><a href="/Leagues/TeamProfile?VenueId=200025&amp;TeamId=#{team_id}) +
        %(&amp;LeagueId=200082&amp;SeasonId=1500001&amp;DivisionId=#{division_id}">#{team_name}</a></td>) +
        %(<td class="played">7</td></tr>)
      }.join
      %(<h3>#{name}</h3><table class="STTable"><tr><td></td><td>Team</td><td>Pld</td></tr>#{rows}</table>)
    }.join

    %(<html><body><h1>Bardon Mondays - 2026 Spring - Current Standings</h1>#{body}</body></html>)
  end

  # The real standings row, all thirteen cells of it: position | team | Pld |
  # W | L | D | FF | FA | F | A | Dif | B | Pts. `teams` entries are
  # [name, team_id, [played, won, lost, drawn, ff, fa, f, a, dif, bonus, pts]].
  def full_standings_html(*divisions)
    body = divisions.map { |name, division_id, teams|
      rows = teams.map { |team_name, team_id, stats|
        cells = [ "<td>tiebreak</td>",
                  %(<td class="STTeamCell"><a href="/Leagues/TeamProfile?VenueId=200025&amp;TeamId=#{team_id}) +
                  %(&amp;LeagueId=200082&amp;SeasonId=1500001&amp;DivisionId=#{division_id}">#{team_name}</a></td>) ] +
                  stats.map { |v| "<td>#{v}</td>" }
        "<tr>#{cells.join}</tr>"
      }.join
      %(<h3>#{name}</h3><table class="STTable"><tr><td></td><td>Team</td><td>Pld</td><td>W</td><td>L</td>) +
        %(<td>D</td><td>FF</td><td>FA</td><td>F</td><td>A</td><td>Dif</td><td>B</td><td>Pts</td></tr>#{rows}</table>)
    }.join

    %(<html><body><h1>Bardon Mondays - 2026 Spring - Current Standings</h1>#{body}</body></html>)
  end

  # Two pages are fetched per sync — the standings and the draw — so the stub
  # has to answer by URL, and it keeps them for the tests that care what was
  # asked for.
  def sync_pages(draw:, standings:)
    @requested = []
    pages = lambda do |url, *|
      @requested << url.to_s
      url.to_s.include?("Standings") ? standings : draw
    end
    URI.stub(:open, pages) { SpawtzScraper.new(@team).sync_fixtures }
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

  test "a stranded fixture holding entered stats is kept for a human to resolve" do
    sync([ [ "Mon 24 Aug 2026", "7:40PM", "The Long Johns", "(not played)" ] ])
    stranded = @season.fixtures.sole
    stranded.appearances.create!(player: players(:john))
    2.times { stranded.touchdowns.create!(scorer: players(:john)) }

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

  # ── FINALS ────────────────────────────────────────────────────────────────
  #
  # The extra leading cell used to shift every read one place left, and it did
  # not fail safely: Time.parse accepted "Semi Final 1 Mon 24 Aug 2026" rather
  # than rejecting it, so every final ever played was stored at midnight, with
  # the court name as the opponent and no score — awaiting_result forever.

  test "a finals row is read past the round label" do
    sync_html(finals_html([ [ "Semi Final 1", "Mon 24 Aug 2026", "7:40PM", "Le Mans", "6 - 4" ] ]))

    final = @season.fixtures.sole
    assert_equal Time.zone.parse("24 Aug 2026 7:40PM"), final.date
    assert_equal "Le Mans", final.opponent_name
    assert_equal [ 6, 4 ], [ final.our_score, final.opponent_score ]
  end

  test "a finals row records which round it was" do
    sync_html(finals_html([ [ "Grand Final", "Mon 31 Aug 2026", "8:15PM", "Da Boiiis", "5 - 3" ] ]))

    final = @season.fixtures.sole
    assert_equal "Grand Final", final.finals_label
    assert final.final?
  end

  test "an ordinary row is not a final" do
    sync([ [ "Mon 27 Jul 2026", "8:25PM", "Le Mans", "5 - 4" ] ])

    assert_not @season.fixtures.sole.final?
  end

  test "a row of any other width is left alone rather than guessed at" do
    sync_html("<html><body><table>" \
      "<tr><td>Mon 27 Jul 2026</td><td>8:25PM</td><td>Field 1</td><td>Le Mans</td>" \
      "<td>5 - 4</td><td>extra</td><td>and another</td></tr>" \
      "</table></body></html>")

    assert_equal 0, @season.fixtures.reload.count,
      "a seven-cell row means Spawtz changed the page, and guessing at a new layout is the bug"
  end

  # ── THE DIVISION AND THE LADDER ───────────────────────────────────────────
  #
  # One TRL league holds more than one division, and the app used to pass
  # DivisionId: 0 and throw the answer away. It is the Social league's grouping
  # key: ranking a Mixed player against a Men's player is the exact distortion
  # that board exists to prevent.

  MIXED = [ "Mixed 1/2", "1402621", [ [ "DUNDA", "202987" ], [ "Cunning Stunts", "208205" ], [ ".BYEmixed", "202798" ] ] ].freeze
  MENS  = [ "Men's", "1402627", [ [ "Just The Lads", "203043" ], [ "Warthogs", "99999" ],
                                  [ "Le Mans", "1404697" ], [ ".BYEmens", "202799" ] ] ].freeze

  def sync_with_standings
    sync_pages(draw: draw_html([ [ "Mon 27 Jul 2026", "8:25PM", "Le Mans", "5 - 4" ] ]),
               standings: standings_html(MIXED, MENS))
  end

  test "the division a team plays in is read off the ladder it stands in" do
    sync_with_standings

    assert_equal "1402627", @team.reload.spawtz_division_id
    assert_equal "Men's", @team.division_name
  end

  test "the draw is asked for by division rather than with a zero" do
    sync_with_standings

    draw = @requested.find { |url| url.include?("TeamProfile") }
    assert_includes draw, "DivisionId=1402627"
  end

  test "where the team finished is recorded against the season" do
    sync_with_standings

    @season.reload
    assert_equal 2, @season.ladder_position
    assert_equal 3, @season.ladder_size, "a bye is not a team you can finish above"
  end

  test "a team that appears in no ladder leaves the division alone" do
    @team.update!(spawtz_team_id: "404404")

    sync_pages(draw: draw_html([ [ "Mon 27 Jul 2026", "8:25PM", "Le Mans", "5 - 4" ] ]),
               standings: standings_html(MIXED))

    assert_nil @team.reload.spawtz_division_id
    assert_nil @season.reload.ladder_position
  end

  test "a standings page that cannot be fetched does not stop the draw syncing" do
    sync_pages(draw: draw_html([ [ "Mon 27 Jul 2026", "8:25PM", "Le Mans", "5 - 4" ] ]), standings: "")

    assert_equal 1, @season.fixtures.reload.count
    assert_nil @team.reload.spawtz_division_id
  end

  # ── THE FULL LADDER ───────────────────────────────────────────────────────
  #
  # ladder_position/ladder_size say where we finished; Standing is the table
  # that number was read off, kept in full so the Season screen can show every
  # team rather than just ours.

  FULL_MENS = [ "Men's", "1402627", [
    [ "Just The Lads", "203043", [ 7, 6, 1, 0, 0, 0, 46, 23, 23, 7, 31 ] ],
    [ "Warthogs",      "99999",  [ 7, 4, 3, 0, 0, 0, 35, 23, 12, 6, 22 ] ],
    [ ".BYEmens",      "202799", [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ] ]
  ] ].freeze

  FULL_MIXED = [ "Mixed 1/2", "1402621", [
    [ "DUNDA", "202987", [ 7, 6, 0, 1, 0, 0, 49, 17, 32, 8, 34 ] ]
  ] ].freeze

  def sync_with_full_standings(*divisions)
    sync_pages(draw: draw_html([ [ "Mon 27 Jul 2026", "8:25PM", "Le Mans", "5 - 4" ] ]),
               standings: full_standings_html(*divisions))
  end

  test "every team in our division lands on the ladder" do
    sync_with_full_standings(FULL_MENS)

    assert_equal [ "Just The Lads", "Warthogs" ], @season.standings.by_position.pluck(:team_name)
  end

  test "a bye is not given a row on the ladder" do
    sync_with_full_standings(FULL_MENS)

    assert_not @season.standings.exists?(team_name: ".BYEmens")
  end

  test "a team from another division does not appear on our ladder" do
    sync_with_full_standings(FULL_MIXED, FULL_MENS)

    assert_not @season.standings.exists?(team_name: "DUNDA")
  end

  test "our own row is the one the season screen highlights" do
    sync_with_full_standings(FULL_MENS)

    us = @season.standings.find_by(team_name: "Warthogs")
    assert us.us?(@team)
    assert_not @season.standings.find_by(team_name: "Just The Lads").us?(@team)
  end

  test "every stat column is read into the row, negative difference included" do
    sync_with_full_standings([ "Men's", "1402627", [
      [ "Warthogs", "99999", [ 7, 2, 5, 0, 1, 0, 20, 42, -22, 4, 8 ] ]
    ] ])

    row = @season.standings.sole
    assert_equal [ 1, 7, 2, 5, 0, 1, 0, 20, 42, -22, 4, 8 ],
      [ row.position, row.played, row.won, row.lost, row.drawn, row.forfeits_for,
        row.forfeits_against, row.points_for, row.points_against, row.difference,
        row.bonus_points, row.points ]
  end

  test "the ladder is replaced wholesale on the next sync" do
    sync_with_full_standings(FULL_MENS)
    assert_equal 2, @season.standings.count

    sync_with_full_standings([ "Men's", "1402627", [ [ "Warthogs", "99999", [ 8, 5, 3, 0, 0, 0, 40, 30, 10, 5, 25 ] ] ] ])

    assert_equal [ "Warthogs" ], @season.standings.reload.pluck(:team_name)
    assert_equal 25, @season.standings.sole.points
  end

  test "a standings row of an unexpected width is skipped rather than guessed at" do
    sync_with_standings

    assert_equal 0, @season.standings.reload.count,
      "the minimal standings fixture has too few cells to be a real row — it must be skipped, not misread"
  end
end
