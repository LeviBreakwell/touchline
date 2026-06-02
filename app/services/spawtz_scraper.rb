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

      fixture = season.fixtures.find_or_initialize_by(date: date)
      fixture.assign_attributes(
        opponent_name: opponent,
        our_score: our_score,
        opponent_score: opponent_score
      )
      fixture.save!
    end
  rescue OpenURI::HTTPError, SocketError => e
    Rails.logger.error("SpawtzScraper#sync_fixtures failed for team #{@team.id}: #{e.message}")
  end

  private

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
