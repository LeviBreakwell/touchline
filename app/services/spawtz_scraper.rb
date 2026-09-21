require "open-uri"

class SpawtzScraper
  BASE_SPAWTZ = "https://trl.spawtz.com"
  USER_AGENT = "Touchline/1.0"

  # Date | Time | Court | Opposition | Result. A finals round is announced by
  # its own single-cell "td.FTitle" row ("Semi Final 1", "Grand Final")
  # immediately before the ordinary row it labels — Spawtz used to instead
  # push the round name into an extra cell in front of the date on the same
  # row, which the FINALS_CELLS case below still reads if that ever comes
  # back.
  ORDINARY_CELLS = 5
  FINALS_CELLS   = 6

  # Position | Team | Pld | W | L | D | FF | FA | F | A | Dif | B | Pts — the
  # full row Spawtz's standings table publishes for one division.
  STANDINGS_CELLS = 13

  def initialize(team)
    @team = team
  end

  def sync_fixtures
    return unless @team.linked_to_spawtz?

    refresh_season_if_changed

    # The standings come first: they are where the division is named, and the
    # draw should be asked for by division rather than with the 0 the app used
    # to send.
    standings = fetch_standings
    capture_division(standings)

    url = "#{BASE_SPAWTZ}/Leagues/TeamProfile?" + URI.encode_www_form(
      VenueId: @team.spawtz_venue_id,
      LeagueId: @team.spawtz_league_id,
      SeasonId: @team.spawtz_season_id,
      DivisionId: @team.spawtz_division_id.presence || 0,
      TeamId: @team.spawtz_team_id
    )

    doc = Nokogiri::HTML(URI.open(url, "User-Agent" => USER_AGENT))
    season = find_or_create_season(standings)
    record_ladder(season, standings)
    record_standings(season, standings)

    seen_ids = []
    pending_finals_label = nil

    doc.css("table tr").each do |row|
      # A title row announces the round for the very next draw row and holds
      # nothing else worth reading off it.
      if (title = row.at_css("td.FTitle"))
        pending_finals_label = title.text.strip.presence
        next
      end

      cells = row.css("td")
      next if cells.size < ORDINARY_CELLS
      next unless draw_row?(cells)

      # A finals row is the ordinary five cells with the round's name pushed in
      # front of them, so everything the parser wants sits one place right.
      offset = cells.size - ORDINARY_CELLS

      date_str    = "#{cells[offset].text.strip} #{cells[offset + 1].text.strip}"
      opponent    = cells[offset + 3].text.strip
      result_str  = cells[offset + 4].text.strip
      finals_label = offset.positive? ? cells[0].text.strip.presence : pending_finals_label
      pending_finals_label = nil

      next if opponent.blank?

      date = parse_datetime(date_str)
      next unless date

      our_score, opponent_score = parse_result(result_str)

      fixture = match_fixture(season, date, opponent, seen_ids)
      fixture.assign_attributes(
        date: date,
        opponent_name: opponent,
        our_score: our_score,
        opponent_score: opponent_score,
        finals_label: finals_label
      )
      fixture.save!
      seen_ids << fixture.id

      # A result landing can confirm a sheet entered days earlier — or reveal
      # that it overruns what TRL actually recorded.
      fixture.refresh_stats_verification!
    end

    prune_withdrawn(season, seen_ids)
  rescue OpenURI::HTTPError, SocketError => e
    Rails.logger.error("SpawtzScraper#sync_fixtures failed for team #{@team.id}: #{e.message}")
  end

  private

  # The draw publishes rows of one of exactly two shapes. Reading any other
  # width as a fixture is how the finals shift went unnoticed for a season:
  # Time.parse accepted the shifted string rather than rejecting it, so every
  # final was stored at midnight with the court name as the opponent. A row
  # that is neither shape means Spawtz has changed the page, and guessing at a
  # new layout is exactly what must not happen — skip it and say so.
  def draw_row?(cells)
    return true if [ ORDINARY_CELLS, FINALS_CELLS ].include?(cells.size)

    Rails.logger.error(
      "SpawtzScraper: skipping a #{cells.size}-cell draw row for team #{@team.id} — " \
      "expected #{ORDINARY_CELLS} or #{FINALS_CELLS}. The Spawtz layout has changed."
    )
    false
  end

  # Spawtz publishes no per-match id — the fixture rows carry no link we could
  # key on — so a fixture's identity has to be reconstructed from the draw each
  # time. Exact kickoff first, then "same day, same opponent", which is what a
  # reschedule looks like: TRL republishes the whole round and every kickoff
  # shifts by a few minutes. Without that fallback a moved time reads as a brand
  # new fixture and the original is stranded as a same-day duplicate — which is
  # exactly how six ghost fixtures accumulated in the 2026 Winter season.
  #
  # Skipping ids already claimed by this scrape keeps a genuine double-header
  # honest: the second row can only match the fixture the first one didn't take.
  def match_fixture(season, date, opponent, seen_ids)
    scope = season.fixtures.where.not(id: seen_ids)

    scope.find_by(date: date) ||
      scope.where(opponent_name: opponent, date: date.all_day).order(:date).first ||
      season.fixtures.new
  end

  # The draw is the source of truth, so a fixture TRL has dropped should go too.
  # Two guards keep that from eating real data: a scrape that parsed no rows at
  # all (page moved, season rolled, HTML changed shape) must never be read as
  # "TRL cancelled everything", and anything already carrying a score or a
  # single entered row is left alone regardless — a half-parsed page must not
  # be able to destroy entered stats. A stranded fixture with stats on it is a
  # duplicate a human should look at, not one we should silently delete.
  def prune_withdrawn(season, seen_ids)
    return if seen_ids.empty?

    season.fixtures
          .where.not(id: seen_ids)
          .where(our_score: nil, opponent_score: nil)
          .without_stats
          .find_each do |fixture|
      Rails.logger.info(
        "SpawtzScraper: pruning fixture #{fixture.id} (#{fixture.date} v #{fixture.opponent_name}) " \
        "— no longer in the TRL draw for team #{@team.id}"
      )
      fixture.destroy!
    end
  end

  def refresh_season_if_changed
    return if @team.trl_location_slug.blank?

    leagues = TrlScraper.leagues(@team.trl_location_slug)
    current = leagues.find { |l| l[:league_id] == @team.spawtz_league_id }
    return unless current
    return if current[:season_id] == @team.spawtz_season_id

    @team.update!(spawtz_season_id: current[:season_id])
  rescue StandardError => e
    Rails.logger.error("SpawtzScraper#refresh_season_if_changed failed for team #{@team.id}: #{e.message}")
  end

  def find_or_create_season(standings)
    season = @team.seasons.find_or_initialize_by(spawtz_season_id: @team.spawtz_season_id)
    if season.new_record? || season.name.start_with?("Season ")
      season.name = competition_name(standings) || "Season #{@team.spawtz_season_id}"
      season.save!
    end
    season
  end

  def fetch_standings
    url = "#{BASE_SPAWTZ}/Leagues/Standings?" + URI.encode_www_form(
      VenueId: @team.spawtz_venue_id,
      LeagueId: @team.spawtz_league_id,
      SeasonId: @team.spawtz_season_id
    )
    Nokogiri::HTML(URI.open(url, "User-Agent" => USER_AGENT))
  rescue OpenURI::HTTPError, SocketError => e
    Rails.logger.error("SpawtzScraper#fetch_standings failed for team #{@team.id}: #{e.message}")
    nil
  end

  def competition_name(standings)
    standings&.at_css("h1, h2")&.text&.strip&.sub(/ - Current Standings$/, "")
  end

  # Spawtz publishes one standings table per division, each under an <h3> that
  # names it, and every team in it links back to itself carrying the division
  # it belongs to. So the division is found the only way it can be: by looking
  # for ourselves in the ladders and reading off which one we are standing in.
  def capture_division(standings)
    link = team_link(standings)
    return if link.nil?

    table = link.ancestors("table").first
    @team.update!(
      spawtz_division_id: link[:href][/DivisionId=(\d+)/, 1],
      division_name: table&.previous_element&.text&.strip.presence
    )
  end

  # Where the Team stands in its division, which is the only place "finish top
  # of the ladder" can come from. Re-read every sync, so it is the final
  # position once the season stops moving.
  def record_ladder(season, standings)
    row = team_link(standings)&.ancestors("tr")&.first
    return if row.nil?

    rows = row.ancestors("table").first.css("tr")
    # The first row is the header, and Spawtz gives a bye its own standing row.
    contenders = rows.drop(1).reject { |tr| tr.at_css(".STTeamCell")&.text.to_s.strip.start_with?(".BYE") }

    season.update!(
      ladder_position: contenders.index(row)&.+(1),
      ladder_size: contenders.size
    )
  end

  # The same division table, in full, so the Season screen can show every
  # team's row rather than just our own position. Re-read and replaced whole
  # each sync — a bye's row is dropped exactly as record_ladder drops it, and a
  # team that changed its name is a new row here rather than a stale one kept
  # around under the old one.
  def record_standings(season, standings)
    row = team_link(standings)&.ancestors("tr")&.first
    return if row.nil?

    rows = row.ancestors("table").first.css("tr").drop(1)
      .reject { |tr| tr.at_css(".STTeamCell")&.text.to_s.strip.start_with?(".BYE") }

    seen_ids = rows.each_with_index.filter_map { |tr, index| upsert_standing(season, tr, index + 1) }
    season.standings.where.not(id: seen_ids).destroy_all
  end

  def upsert_standing(season, tr, position)
    cells = tr.css("td")
    unless cells.size == STANDINGS_CELLS
      Rails.logger.error(
        "SpawtzScraper: skipping a #{cells.size}-cell standings row for team #{@team.id} — " \
        "expected #{STANDINGS_CELLS}. The Spawtz layout has changed."
      )
      return nil
    end

    link = tr.at_css("td.STTeamCell a")
    spawtz_team_id = link&.[](:href).to_s[/TeamId=(\d+)/, 1]
    return nil if spawtz_team_id.blank?

    entry = season.standings.find_or_initialize_by(spawtz_team_id: spawtz_team_id)
    entry.update!(
      position: position,
      team_name: link.text.strip,
      played: cells[2].text.strip.to_i,
      won: cells[3].text.strip.to_i,
      lost: cells[4].text.strip.to_i,
      drawn: cells[5].text.strip.to_i,
      forfeits_for: cells[6].text.strip.to_i,
      forfeits_against: cells[7].text.strip.to_i,
      points_for: cells[8].text.strip.to_i,
      points_against: cells[9].text.strip.to_i,
      difference: cells[10].text.strip.to_i,
      bonus_points: cells[11].text.strip.to_i,
      points: cells[12].text.strip.to_i
    )
    entry.id
  end

  # Our own name in whichever ladder it appears in, matched on the Spawtz team
  # id rather than the name — two divisions can and do carry teams with nearly
  # the same name. Read off the team cell specifically: the position cell in
  # front of it holds Spawtz's tie-break tooltip, whose links have no href.
  def team_link(standings)
    standings&.css("table.STTable td.STTeamCell a")
             &.find { |link| link[:href].to_s.include?("TeamId=#{@team.spawtz_team_id}") }
  end

  # "Mon 11 May 2026 7:40PM" → ActiveSupport::TimeWithZone
  def parse_datetime(str)
    Time.zone.parse(str.sub(/\A\w{3} /, ""))
  rescue ArgumentError, TypeError
    nil
  end

  # "5 - 3" → [5, 3]; "(not played)" → [nil, nil]
  def parse_result(str)
    if str =~ /\A(\d+)\s*-\s*(\d+)\z/
      [ $1.to_i, $2.to_i ]
    else
      [ nil, nil ]
    end
  end
end
