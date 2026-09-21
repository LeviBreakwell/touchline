# Something a User has done, recorded permanently and unlocking a Title.
#
# Two shapes of one thing (#21). A **tiered** accolade is a running total
# crossing a rung: monotonic, earned once per rung, never lost, only
# not-yet-reached. A **repeatable** is an event that can happen again — a grand
# final, an MVP — paying XP every time and carrying a count.
#
# The threshold-vs-condition split leaked immediately, which is why it is not
# the split used here: "score in five straight games" is a condition that can
# be broken and belongs cleanly to neither.
class Accolade
  # Fixed, never bespoke, so accolade #40 stays data entry rather than an
  # economy change. MVP is the one line of the economy that is its own rate
  # (#20) — it is paid every game somebody tops the sheet, which is far more
  # often than any of these.
  XP = { common: 2, uncommon: 6, rare: 20, mvp: 4 }.freeze

  # Ladders are scaled per stat: a shared ladder cannot work, because the same
  # rungs are wildly different achievements. Twenty bomb catches is eighteen
  # games; twenty critical errors is two hundred.
  LADDERS = {
    appearances:        [ 5, 15, 25, 60, 120 ],
    tries:              [ 5, 15, 25, 50, 100 ],
    assists:            [ 3, 10, 15, 25, 50 ],
    bomb_catches:       [ 10, 15, 30, 75, 150 ],
    dropped_bombs:      [ 2, 3, 10, 15, 30 ],
    critical_errors:    [ 1, 2, 3, 10, 15 ]
  }.freeze

  RARITIES = %i[common common uncommon uncommon rare].freeze

  # A Title is chosen by the Player, never assigned — which is the only reason
  # the negative ladders are bearable. "Butterfingers" is funny worn on
  # purpose and unpleasant pinned on somebody.
  TITLES = {
    appearances:        [ "Regular", "Clubman", "Stalwart", "Veteran", "Life Member" ],
    tries:              [ "Scorer", "Finisher", "Poacher", "Try Machine", "Century Club" ],
    assists:            [ "Distributor", "Playmaker", "The Link", "Architect", "Maestro" ],
    bomb_catches:       [ "Safe Hands", "High Ball", "Bomb Magnet", "The Wall", "Skyhook" ],
    dropped_bombs:      [ "Butterfingers", "Greasy Palms", "Slippery Customer", "Hands of Stone", "Gravity Always Wins" ],
    critical_errors:    [ "Generous", "Gift Wrapped", "Their Best Player", "Double Agent", "Honorary Opposition" ]
  }.freeze

  NOUNS = {
    appearances: "appearance", tries: "try", assists: "assist",
    bomb_catches: "bomb catch", dropped_bombs: "dropped bomb",
    critical_errors: "critical error"
  }.freeze

  # The glyph each one wears in the showcase — the only place accolade art
  # appears at all. A whole ladder shares one glyph, which is what keeps the
  # art bill at twelve files rather than thirty-six.
  GLYPHS = {
    appearances: "appearances", tries: "tries", assists: "assists",
    bomb_catches: "bomb-catches", dropped_bombs: "dropped-bombs",
    critical_errors: "critical-errors"
  }.freeze

  REPEATABLES = [
    { key: "mvp",               title: "Best on Ground",    rarity: :mvp,    glyph: "mvp",
      description: "Most points in a game, Plays included" },
    { key: "hat_trick",         title: "Hat-trick Hero",    rarity: :uncommon, glyph: "hat-trick",
      description: "Three tries in one game" },
    { key: "full_house",        title: "Full House",        rarity: :uncommon, glyph: "full-house",
      description: "Everyone who took the field scored" },
    { key: "undefeated_season", title: "Invincible",        rarity: :rare,   glyph: "undefeated",
      description: "A season without losing a game" },
    { key: "grand_final",       title: "Premiership Winner", rarity: :rare,  glyph: "grand-final",
      description: "Won a grand final" },
    { key: "top_of_the_ladder", title: "Minor Premier",     rarity: :rare,   glyph: "top-of-the-ladder",
      description: "Finished top of the division" },
    { key: "clive_churchill",   title: "Clive Churchill Medal", rarity: :rare, glyph: "clive-churchill",
      description: "MVP in a grand final" }
  ].freeze

  attr_reader :key, :title, :kind, :rarity, :glyph, :description, :stat, :threshold

  def initialize(key:, title:, kind:, rarity:, glyph:, description:, stat: nil, threshold: nil)
    @key = key
    @title = title
    @kind = kind
    @rarity = rarity
    @glyph = glyph
    @description = description
    @stat = stat
    @threshold = threshold
  end

  def xp = XP.fetch(rarity)
  def tiered? = kind == :tiered
  def repeatable? = kind == :repeatable

  # A rare accolade also unlocks a Card banner.
  def unlocks_banner? = rarity == :rare

  def self.all
    @all ||= begin
      tiered = LADDERS.flat_map do |stat, rungs|
        rungs.each_with_index.map do |threshold, rung|
          new(key: "#{stat}_#{threshold}", title: TITLES.fetch(stat)[rung], kind: :tiered,
              rarity: RARITIES[rung], glyph: GLYPHS.fetch(stat), stat: stat, threshold: threshold,
              description: "#{threshold} #{NOUNS.fetch(stat).pluralize(threshold)}")
        end
      end

      repeatable = REPEATABLES.map do |spec|
        new(kind: :repeatable, **spec)
      end

      (tiered + repeatable).index_by(&:key).freeze
    end
  end

  def self.[](key) = all[key.to_s]
  def self.ladder(stat) = all.values.select { |accolade| accolade.stat == stat }.sort_by(&:threshold)
  def self.repeatable = all.values.select(&:repeatable?)

  # What each ladder is counting, read off a StatLine. Only `appearances`
  # differs from its own name — a StatLine calls those games — and the one
  # mapping lives here so the ledger that awards a rung and the profile that
  # shows the distance to it cannot disagree about what the rung counts.
  def self.totals(line)
    LADDERS.keys.index_with { |stat| line.public_send(stat == :appearances ? :games : stat) }
  end
end
