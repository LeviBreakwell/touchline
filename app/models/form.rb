# How this season compares with the rest of somebody's career.
#
# The comparison is against themselves, because nothing else has data: a Team
# is thirteen people, so a percentile is worth 7.7 points a rank, and
# "competition" and "app-wide" have no data source at all.
#
# An arrow and a colour, three states, and no new numbers on the page.
class Form
  # Either side of the comparison needs enough games to mean anything. Below
  # this the answer is "we can't tell", which is a different thing from level
  # and has to look different — an absent arrow reads as level.
  ENOUGH_GAMES = 3

  # How far either side of the career rate still counts as holding form. A
  # season that is one try better over ten games is not a trend.
  DEAD_BAND = 0.10

  # Up is not good for everything. A rising drop count is a falling player.
  POLARITY = {
    tries: :up_is_good, assists: :up_is_good, points: :up_is_good,
    bomb_catches: :up_is_good, catch_rate: :up_is_good,
    dropped_bombs: :up_is_bad, critical_errors: :up_is_bad
  }.freeze

  Reading = Struct.new(:stat, :direction, :certain, keyword_init: true) do
    def certain? = certain
    def level? = direction == :level

    # Whether the arrow is the direction this player would want.
    def good?
      return false if level?
      (Form::POLARITY.fetch(stat) == :up_is_good) == (direction == :up)
    end
  end

  def initialize(season:, career:)
    @season = season
    @career = career
  end

  def on(stat)
    certain = @season.games >= ENOUGH_GAMES && @career.games >= ENOUGH_GAMES
    Reading.new(stat: stat, direction: direction_for(stat), certain: certain)
  end

  private

  def direction_for(stat)
    now, ever = rate(@season, stat), rate(@career, stat)
    return :level if now.nil? || ever.nil?
    return :level if ever.zero? && now.zero?
    return :up if ever.zero?

    change = (now - ever) / ever.to_f
    return :level if change.abs <= DEAD_BAND
    change.positive? ? :up : :down
  end

  # Everything is per game except the rates that are already rates.
  def rate(line, stat)
    return line.catch_rate if stat == :catch_rate
    return nil if line.games.zero?

    line.public_send(stat) / line.games.to_f
  end
end
