# Every GameStat for one Fixture, saved as a unit.
#
# The sheet is the only place stats are written, which is what makes TRL's
# published scoreline enforceable: a roster can never be credited with more
# tries — or more assists — than TRL says the team scored. Before the result is
# published there is nothing to check against, so an early sheet saves happily
# and its Fixture simply stays unverified until TRL catches up.
class StatSheet
  Row = Struct.new(:player_id, :tries, :assists, :played)

  attr_reader :fixture, :error

  # rows: anything responding to [] for :player_id, :tries, :assists, :played
  def initialize(fixture, rows)
    @fixture = fixture
    @rows = rows.map do |row|
      Row.new(row[:player_id].to_i, row[:tries].to_i, row[:assists].to_i, cast_played(row[:played]))
    end
  end

  # player_id => GameStat, with the submitted values assigned whether or not
  # they saved, so a rejected sheet can be re-rendered as the Member typed it.
  def stats
    @stats ||= @rows.to_h do |row|
      stat = fixture.game_stats.find_or_initialize_by(player_id: row.player_id)
      stat.assign_attributes(tries: row.tries, assists: row.assists, played: row.played)
      [ row.player_id, stat ]
    end
  end

  def save
    return false unless fits_official_result?

    GameStat.transaction do
      # Two passes: every row is first pushed down to the lower of its old and
      # new value, then up to its new value. Moving a try from one player to
      # another would otherwise trip GameStat's cap half-way through the sheet,
      # since the receiving row can be written before the giving one.
      write { |row, stat| [ [ row.tries, stat.tries_in_database.to_i ].min, [ row.assists, stat.assists_in_database.to_i ].min ] }
      write { |row, _stat| [ row.tries, row.assists ] }
    end

    fixture.refresh_stats_verification!
    true
  rescue ActiveRecord::RecordInvalid => e
    @error = e.record.errors.full_messages.to_sentence
    false
  end

  private

  def write
    @rows.each do |row|
      stat = stats[row.player_id]
      tries, assists = yield(row, stat)
      stat.assign_attributes(tries: tries, assists: assists, played: row.played)
      stat.save!
    end
  end

  def fits_official_result?
    cap = fixture.official_tries
    return true if cap.nil?

    tries = total(:tries)
    if tries > cap
      @error = "TRL has this game at #{cap} #{'try'.pluralize(cap)}, so that is the most the roster can be credited with. " \
               "This sheet adds up to #{tries} — take #{tries - cap} off to save it."
      return false
    end

    assists = total(:assists)
    if assists > cap
      @error = "TRL has this game at #{cap} #{'try'.pluralize(cap)}, so at most #{cap} of them can be assisted. " \
               "This sheet adds up to #{assists} assists — take #{assists - cap} off to save it."
      return false
    end

    true
  end

  # The sheet's own rows plus any stat already saved for a Player it leaves out,
  # which still counts against TRL's ceiling.
  def total(field)
    @rows.sum(&field) + fixture.game_stats.where.not(player_id: @rows.map(&:player_id)).sum(field)
  end

  def cast_played(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end
end
