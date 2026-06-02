class TrlBrowserController < ApplicationController
  before_action :require_authentication

  def locations
    @locations = TrlScraper.locations
  end

  def leagues
    @location_slug = params[:location]
    @leagues = TrlScraper.leagues(@location_slug)
  end

  def pick
    @venue_id      = params[:venue_id]
    @league_id     = params[:league_id]
    @season_id     = params[:season_id]
    @location_slug = params[:location_slug]
    result = TrlScraper.teams(@venue_id, @league_id, @season_id)
    @competition_name = result[:page_title]
    @teams = result[:teams]
  end
end
