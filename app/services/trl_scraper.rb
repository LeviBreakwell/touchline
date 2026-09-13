require "open-uri"

class TrlScraper
  BASE_TRL = "https://www.trl.com.au"
  BASE_SPAWTZ = "https://trl.spawtz.com"
  USER_AGENT = "Touchline/1.0"

  def self.locations
    doc = Nokogiri::HTML(URI.open("#{BASE_TRL}/locations", "User-Agent" => USER_AGENT))
    doc.css("a[href^='/location/']").filter_map do |a|
      slug = a["href"].delete_prefix("/location/")
      name = a.text.strip
      next if name.blank? || slug.blank?
      { name: name, slug: slug }
    end.uniq { |l| l[:slug] }
  rescue OpenURI::HTTPError, SocketError => e
    Rails.logger.error("TrlScraper.locations failed: #{e.message}")
    []
  end

  def self.leagues(slug)
    doc = Nokogiri::HTML(URI.open("#{BASE_TRL}/location/#{slug}", "User-Agent" => USER_AGENT))
    seen = {}
    leagues = []

    # Each competition block: div.location_stats-item contains a day label + fixture/ladder links
    doc.css(".location_stats-item").each do |item|
      label = item.at_css(".text-size-large, .text-weight-bold")&.text&.strip
      fixture_link = item.at_css("a[href*='spawtz.com/Leagues/fixtures'], a[href*='spawtz.com/Leagues/Fixtures']")
      next unless fixture_link

      params = parse_query(fixture_link["href"])
      next unless params["VenueId"] && params["LeagueId"] && params["SeasonId"]
      league_id = params["LeagueId"]
      next if seen[league_id]
      seen[league_id] = true

      leagues << {
        name: label.presence || "League #{league_id}",
        venue_id: params["VenueId"],
        league_id: league_id,
        season_id: params["SeasonId"]
      }
    end
    leagues
  rescue OpenURI::HTTPError, SocketError => e
    Rails.logger.error("TrlScraper.leagues(#{slug}) failed: #{e.message}")
    []
  end

  def self.teams(venue_id, league_id, season_id)
    url = "#{BASE_SPAWTZ}/Leagues/Standings?" + URI.encode_www_form(
      VenueId: venue_id, LeagueId: league_id, SeasonId: season_id
    )
    doc = Nokogiri::HTML(URI.open(url, "User-Agent" => USER_AGENT))

    # Page heading gives us the full competition name (e.g. "Bardon Mondays - 2026 Winter - Men's - Current Standings")
    page_title = doc.at_css("h1, h2, .page-title")&.text&.strip&.sub(/ - Current Standings$/, "")

    teams = doc.css("a[href*='TeamProfile']").filter_map do |a|
      params = parse_query(a["href"])
      team_id = params["TeamId"]
      name = a.text.strip
      next if name.blank? || team_id.blank?
      { name: name, team_id: team_id }
    end.uniq { |t| t[:team_id] }

    { page_title: page_title, teams: teams }
  rescue OpenURI::HTTPError, SocketError => e
    Rails.logger.error("TrlScraper.teams failed: #{e.message}")
    { page_title: nil, teams: [] }
  end

  def self.parse_query(url)
    uri = URI.parse(url.to_s)
    URI.decode_www_form(uri.query.to_s).to_h
  rescue URI::InvalidURIError
    {}
  end
end
