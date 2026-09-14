# One try: the Fixture, the Player who scored it, and optionally the Player who
# assisted it.
#
# The assist is a column here rather than a row of its own because an assist is
# not a thing that happens — it is who passed it. Modelled this way, "assists
# cannot outnumber tries" is true by shape and there is nothing to validate. At
# most one assister: the last pass is the assist, and a ceiling of one is also
# what keeps the official-score check sound.
class Touchdown < ApplicationRecord
  TRY_POINTS    = 8
  ASSIST_POINTS = 4

  belongs_to :fixture
  belongs_to :scorer,   class_name: "Player", foreign_key: :scorer_player_id,   optional: true
  belongs_to :assister, class_name: "Player", foreign_key: :assister_player_id, optional: true

  # Rows with a scorer are the Team's tries. Rows without one are assists
  # imported from the old counters, whose try was never recorded — they count
  # towards nobody's try tally, which is exactly what makes them harmless.
  scope :scored,   -> { where.not(scorer_player_id: nil) }
  scope :assisted, -> { where.not(assister_player_id: nil) }
  scope :verified, -> { joins(:fixture).merge(Fixture.verified) }

  validate :names_somebody
  validate :scorer_is_not_the_assister

  # Entering a try is itself proof that whoever it names took the field.
  after_create :record_appearances
  after_commit :refresh_fixture_verification

  private

  def record_appearances
    [ scorer_player_id, assister_player_id ].compact.each do |player_id|
      Appearance.find_or_create_by!(fixture_id: fixture_id, player_id: player_id)
    end
  end

  def names_somebody
    return if scorer_player_id.present? || assister_player_id.present?
    errors.add(:base, "a touchdown has to name a scorer or an assister")
  end

  # A try assisted by its own scorer is a mis-drag, not a fact about the game.
  def scorer_is_not_the_assister
    return if scorer_player_id.blank? || scorer_player_id != assister_player_id
    errors.add(:assister, "cannot be the player who scored")
  end

  # A Fixture on its way out has nothing left to verify — this fires for
  # destroys too, including the cascade from a Season or Team going away.
  def refresh_fixture_verification
    return if fixture.nil? || fixture.destroyed?
    fixture.refresh_stats_verification!
  end
end
