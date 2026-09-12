# Accolades are awarded, never computed (#21).
#
# Three forces point the same way: a repeatable needs somewhere to keep its
# occurrences, a corrected sheet must not silently take back an accolade
# somebody was shown yesterday, and claiming a roster entry has to write
# everything the banked history earned at once — which is the payoff the claim
# flow exists for.
#
# `subject` is what stops the ledger double-awarding. A tiered accolade is a
# total crossing a rung and happens once, so it has none. A repeatable happens
# again, and an occurrence with no identity cannot be recognised the second
# time the ledger runs — so it carries the thing it happened to, as
# "fixture:123" or "season:7".
class CreateAccoladeAwards < ActiveRecord::Migration[8.0]
  def change
    create_table :accolade_awards do |t|
      t.references :user, null: false, foreign_key: { deferrable: :deferred }
      t.string :key, null: false
      t.string :subject, null: false, default: ""

      t.timestamps
    end
    add_index :accolade_awards, [ :user_id, :key, :subject ], unique: true

    # The three cosmetic slots. One slot, one source: the border is gated by
    # Level and is not chosen at all, so it is not here.
    add_column :users, :title_key, :string
    add_column :users, :banner_key, :string
    add_column :users, :showcase_keys, :string, array: true, default: [], null: false
  end
end
