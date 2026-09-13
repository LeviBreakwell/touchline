# Everything a career page says about one Player on one Team: the totals, the
# part TRL has not checked yet, the seasons they appeared in, and how the
# current one compares with the rest.
#
# A Player belongs to one Team, so this is the **team-scoped** half of
# somebody's record. The account-scoped half — level, accolades, and totals over
# every roster they are on — is Progression and a StatLine across all of their
# Players, because a User is one person however many teams they turn out for.
# A Season belongs to a Team, which is the whole reason the halves exist: "this
# season" and "by season" cannot be asked of an account, only of a Team.
class Career
  attr_reader :player

  def initialize(player)
    @player = player
  end

  def team = player.team

  def line    = @line    ||= player.career_stats
  def pending = @pending ||= player.unconfirmed_stats
  def seasons = @seasons ||= player.seasons_played

  # This season leads on the page: it is the comparison every arrow makes, so
  # it should not be below the fold.
  def season      = seasons.first
  def season_line = @season_line ||= season ? player.season_stats(season) : StatLine.new
  def form        = @form ||= Form.new(season: season_line, career: line)

  def any? = line.any?
end
