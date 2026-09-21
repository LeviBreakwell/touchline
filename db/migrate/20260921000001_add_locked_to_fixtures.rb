# Locking freezes stat entry so a long roster can be scrolled without a touch
# landing on a card as a gesture — see match_ladder_controller. It has to
# outlive the tab it was set from: leaving mid-game and coming back should not
# silently unlock a screen somebody deliberately froze.
class AddLockedToFixtures < ActiveRecord::Migration[8.0]
  def change
    add_column :fixtures, :locked, :boolean, default: false, null: false
  end
end
