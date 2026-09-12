# Writes the accolade rows. Nothing else does.
#
# Awarding is additive and never revoked. A total that goes backwards because
# somebody fixed a sheet still leaves the rung earned, and that is deliberate:
# an accolade shown to somebody yesterday must not quietly disappear today.
class AccoladeLedger
  # Fewer than this and "everybody scored" is not a full house, it is a short
  # bench.
  FULL_HOUSE_MINIMUM = 2

  # A season is not undefeated until it is over, and one game is not a season.
  UNDEFEATED_MINIMUM = 3

  class << self
    # Everything the banked history earned, all at once. This is the payoff the
    # claim flow exists for: a three-season veteran arrives with a whole
    # border era and sixteen accolades in one screen.
    def settle(user)
      settle_totals(user)

      fixtures_played_by(user).each { |fixture| settle_fixture(fixture) }
      seasons_played_by(user).each { |season| settle_season(season) }
    end

    # The tiered ladders. Safe to run on every write: a rung is a total
    # crossing a line, so running it twice changes nothing.
    def settle_totals(user)
      line = StatLine.for(user.players.select(:id))
      totals = {
        appearances: line.games, tries: line.tries, assists: line.assists,
        bomb_catches: line.bomb_catches, dropped_bombs: line.dropped_bombs,
        opposition_assists: line.opposition_assists
      }

      # Read the ledger once rather than asking it thirty times. This runs on
      # every gesture, and all but the first few are rungs already earned.
      already = user.accolade_awards.where(subject: "").pluck(:key).to_set

      Accolade.all.each_value do |accolade|
        next unless accolade.tiered?
        next if already.include?(accolade.key)
        award(user, accolade.key) if totals.fetch(accolade.stat) >= accolade.threshold
      end
    end

    # The per-game repeatables.
    #
    # Deliberately not run on every gesture. MVP moves while a game is being
    # entered — the crown sits on whoever is top after the third try — and an
    # accolade is never taken back, so running this live would hand the same
    # game's MVP to two different people. It runs once the game has settled.
    def settle_fixture(fixture)
      return unless fixture.appearances.exists?

      ladder = MatchLadder.new(fixture, fixture.team)
      played = ladder.played
      subject = subject_for(fixture)

      award_player(ladder.mvp.player, "mvp", subject) if ladder.mvp

      played.each { |row| award_player(row.player, "hat_trick", subject) if row.tries >= 3 }

      if played.size >= FULL_HOUSE_MINIMUM && played.all? { |row| row.tries.positive? }
        played.each { |row| award_player(row.player, "full_house", subject) }
      end

      if grand_final_won?(fixture)
        played.each { |row| award_player(row.player, "grand_final", subject) }
      end
    end

    # The per-season repeatables. A season has to be over for either of them to
    # be true, which is what "all played" means here.
    def settle_season(season)
      fixtures = season.fixtures.to_a
      return if fixtures.size < UNDEFEATED_MINIMUM

      if fixtures.all?(&:played?) && fixtures.none? { |fixture| fixture.result == "loss" }
        award_everyone_who_played(season, "undefeated_season")
      end

      award_everyone_who_played(season, "top_of_the_ladder") if season.won_the_ladder?
    end

    # Recent games and the seasons they belong to, settled in one pass.
    #
    # The window reaches back a month rather than a day because a sheet entered
    # late is still a sheet, and it stops short of the last half day because a
    # game played tonight is still being entered.
    def settle_recent(window: 30.days.ago, settled_after: 12.hours.ago)
      fixtures = Fixture.where(date: window..settled_after)

      fixtures.find_each { |fixture| settle_fixture(fixture) }
      Season.where(id: fixtures.select(:season_id)).find_each { |season| settle_season(season) }
    end

    private

    def award(user, key, subject = "")
      AccoladeAward.create!(user_id: user.id, key: key, subject: subject)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      nil   # already on the ledger, which is the only thing that matters
    end

    def award_player(player, key, subject)
      return if player.nil? || player.user_id.nil?
      award(User.new(id: player.user_id), key, subject)
    end

    def award_everyone_who_played(season, key)
      Player.where(id: Appearance.joins(:fixture).where(fixtures: { season_id: season.id }).select(:player_id))
            .where.not(user_id: nil)
            .find_each { |player| award_player(player, key, subject_for(season)) }
    end

    def grand_final_won?(fixture)
      fixture.finals_label.to_s.match?(/grand final/i) && fixture.result == "win"
    end

    def subject_for(record) = "#{record.class.name.downcase}:#{record.id}"

    def fixtures_played_by(user)
      Fixture.where(id: Appearance.where(player_id: user.players.select(:id)).select(:fixture_id))
    end

    def seasons_played_by(user)
      Season.where(id: fixtures_played_by(user).select(:season_id))
    end
  end
end
