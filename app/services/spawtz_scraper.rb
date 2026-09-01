require "open-uri"

class SpawtzScraper
  BASE_SPAWTZ = "https://trl.spawtz.com"
  USER_AGENT = "Touchline/1.0"

  def initialize(team)
    @team = team
  end

  def sync_fixtures
    return unless @team.spawtz_team_id.present?

    refresh_season_if_changed

    url = "#{BASE_SPAWTZ}/Leagues/TeamProfile?" + URI.encode_www_form(
      VenueId: @team.spawtz_venue_id,
      LeagueId: @team.spawtz_league_id,
      SeasonId: @team.spawtz_season_id,
      DivisionId: 0,
      TeamId: @team.spawtz_team_id
    )

    doc = Nokogiri::HTML(URI.open(url, "User-Agent" => USER_AGENT))
    season = find_or_create_season(doc)

    seen_ids = []

    doc.css("table tr").each do |row|
      cells = row.css("td")
      next if cells.size < 5

      date_str   = "#{cells[0].text.strip} #{cells[1].text.strip}"
      opponent   = cells[3].text.strip
      result_str = cells[4].text.strip

      next if opponent.blank?

      date = parse_datetime(date_str)
      next unless date

      our_score, opponent_score = parse_result(result_str)

      fixture = match_fixture(season, date, opponent, seen_ids)
      fixture.assign_attributes(
        date: date,
        opponent_name: opponent,
        our_score: our_score,
        opponent_score: opponent_score
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
  # "TRL cancelled everything", and anything already carrying a score or a stat
  # sheet is left alone regardless — a half-parsed page must not be able to
  # destroy entered stats. A stranded fixture with stats on it is a duplicate a
  # human should look at, not one we should silently delete.
  def prune_withdrawn(season, seen_ids)
    return if seen_ids.empty?

    season.fixtures
          .where.not(id: seen_ids)
          .where(our_score: nil, opponent_score: nil)
          .where.missing(:game_stats)
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

  def find_or_create_season(_doc)
    season = @team.seasons.find_or_initialize_by(spawtz_season_id: @team.spawtz_season_id)
    if season.new_record? || season.name.start_with?("Season ")
      season.name = fetch_competition_name || "Season #{@team.spawtz_season_id}"
      season.save!
    end
    season
  end

  def fetch_competition_name
    url = "#{BASE_SPAWTZ}/Leagues/Standings?" + URI.encode_www_form(
      VenueId: @team.spawtz_venue_id,
      LeagueId: @team.spawtz_league_id,
      SeasonId: @team.spawtz_season_id
    )
    doc = Nokogiri::HTML(URI.open(url, "User-Agent" => USER_AGENT))
    doc.at_css("h1, h2")&.text&.strip&.sub(/ - Current Standings$/, "")
  rescue OpenURI::HTTPError, SocketError
    nil
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
