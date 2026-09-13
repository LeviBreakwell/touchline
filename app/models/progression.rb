# Everything a User has earned by taking part: XP, the level it buys, the
# accolades on the ledger, and the cosmetics those two unlock.
#
# Points measure performance; XP measures participation. A dropped bomb earns
# the same XP as a try and still costs two points, which is the whole reason
# there are two currencies.
class Progression
  APPEARANCE_XP = 10
  STAT_XP = 1

  def initialize(user, xp: nil, awards: nil, line: nil)
    @user = user
    @xp = xp
    @awards = awards
    @line = line
  end

  # Everyone on one screen at once.
  #
  # A card carries a border, and a border is a level, and a level is every
  # appearance and stat and accolade that User has ever had. Asked one User at
  # a time that is four queries a card; asked like this it is five for the
  # page, however many cards are on it.
  def self.batch(user_ids)
    ids = user_ids.compact.uniq
    return {} if ids.empty?

    appearances = Appearance.joins(:player).where(players: { user_id: ids }).group("players.user_id").count
    tries       = Touchdown.joins(:scorer).where(players: { user_id: ids }).group("players.user_id").count
    assists     = Touchdown.joins(:assister).where(players: { user_id: ids }).group("players.user_id").count
    plays       = Play.joins(:player).where(players: { user_id: ids }).group("players.user_id").count
    awards      = AccoladeAward.where(user_id: ids).group_by(&:user_id)

    User.where(id: ids).to_h do |user|
      earned = awards.fetch(user.id, [])
      xp = (appearances.fetch(user.id, 0) * APPEARANCE_XP) +
           ((tries.fetch(user.id, 0) + assists.fetch(user.id, 0) + plays.fetch(user.id, 0)) * STAT_XP) +
           earned.sum { |award| award.accolade&.xp.to_i }

      [ user.id, new(user, xp: xp, awards: earned) ]
    end
  end

  def line = @line ||= StatLine.for(@user.players.select(:id))

  # There is no cap and no diminishing return. Four games of merely turning up
  # is worth twice anyone's best possible single game, and there is nothing to
  # cap — nor a rule waiting to fire on somebody's best night.
  def xp
    @xp ||= (line.games * APPEARANCE_XP) + (stats_recorded * STAT_XP) + accolade_xp
  end

  # What a card needs: a border, a title, and the wash behind the name. Nothing
  # here touches the stat line, which is the expensive half.
  def cosmetic? = true

  # Every stat recorded against them, sign ignored.
  def stats_recorded = line.tries + line.assists + line.plays.values.sum

  def accolade_xp = awards.sum { |award| award.accolade&.xp.to_i }

  def level = @level ||= Level.for(xp)

  # [earned, needed] through the current level.
  def progress = Level.progress(xp)

  def border = @border ||= Border.for(level)
  def next_border = Border.next_after(level)

  def awards = @awards ||= @user.accolade_awards.order(:created_at).to_a

  # One entry per accolade, however many times it has been earned — a
  # repeatable carries its count (Grand Final ×3) rather than three rows on a
  # profile.
  def earned
    @earned ||= awards.group_by(&:key).filter_map do |key, rows|
      accolade = Accolade[key]
      [ accolade, rows.size ] if accolade
    end.sort_by { |accolade, _count| [ -Accolade::XP.fetch(accolade.rarity), accolade.title ] }
  end

  def earned?(key) = awards.any? { |award| award.key == key }

  def count_of(key) = awards.count { |award| award.key == key }

  def titles = earned.map(&:first)

  def title = Accolade[@user.title_key]&.title

  # A rare accolade also unlocks a Card banner.
  def banners = titles.select(&:unlocks_banner?)

  def banner_class = @user.banner_key.presence && BANNERS[@user.banner_key]

  # Three accolades pinned to the top of a profile, and the only place accolade
  # art appears at all — a row of badges beside every name on a leaderboard
  # would be unreadable.
  SHOWCASE_SLOTS = 3

  def showcase
    @user.showcase_keys.filter_map { |key| Accolade[key] if earned?(key) }.first(SHOWCASE_SLOTS)
  end

  # ── what is still out there ──
  #
  # A profile that lists only what has been earned tells somebody with nothing
  # that there is nothing to get. Both shapes of accolade therefore have to say
  # what they are waiting for, and the tiered ones can say how far off it is.

  # A ladder as the person climbing it sees it: where they are, which rungs are
  # behind them, and what the next one costs. One row per ladder rather than one
  # per rung — six rows say what thirty would, because the rung after next is
  # not a goal until this one is met.
  Climb = Struct.new(:stat, :total, :rungs, :earned_keys, keyword_init: true) do
    def label = Accolade::NOUNS.fetch(stat).pluralize.capitalize
    def noun = Accolade::NOUNS.fetch(stat)

    def earned?(accolade) = earned_keys.include?(accolade.key)
    def next_rung = rungs.find { |accolade| !earned?(accolade) }
    def complete? = next_rung.nil?

    # Whichever rung carries the ladder's glyph — a whole ladder shares one, so
    # any rung will do and the next one is the one being aimed at.
    def face = next_rung || rungs.last

    def to_go = complete? ? 0 : [ next_rung.threshold - total, 0 ].max

    # How far between the last rung earned and the next one. Measured from the
    # rung below rather than from zero, so a bar that is nearly full means
    # nearly there — which is the only thing it is asked.
    def fraction
      return 1.0 if complete?

      from = rungs.take_while { |accolade| earned?(accolade) }.last&.threshold.to_i
      span = next_rung.threshold - from
      return 1.0 if span.zero?

      ((total - from).to_f / span).clamp(0.0, 1.0)
    end
  end

  def climbs
    @climbs ||= begin
      totals = Accolade.totals(line)
      keys = awards.map(&:key).to_set

      Accolade::LADDERS.keys.map do |stat|
        Climb.new(stat: stat, total: totals.fetch(stat), rungs: Accolade.ladder(stat), earned_keys: keys)
      end
    end
  end

  # How many accolades are still out there. Counts rungs, not ladders: thirty
  # tiered plus six one-offs is the whole of it.
  def left_to_earn
    climbs.sum { |climb| climb.rungs.count { |rung| !climb.earned?(rung) } } + unearned_one_offs.size
  end

  # The one-offs nobody has yet. Rarest first, which is also the order they are
  # hardest in — a grand final above a hat-trick.
  def unearned_one_offs
    Accolade.repeatable.reject { |accolade| earned?(accolade.key) }
            .sort_by { |accolade| [ -accolade.xp, accolade.title ] }
  end

  # Which wash a rare accolade paints behind a name. Eight gradients over
  # tokens the app already has, and not one file.
  BANNERS = {
    "appearances_120"       => "banner-silver",
    "tries_100"             => "banner-green",
    "assists_50"            => "banner-blue",
    "bomb_catches_150"      => "banner-orange",
    "dropped_bombs_30"      => "banner-red",
    "opposition_assists_15" => "banner-bronze",
    "undefeated_season"     => "banner-slate",
    "grand_final"           => "banner-gold",
    "top_of_the_ladder"     => "banner-gold"
  }.freeze
end
