# The three tables that replace GameStat's tally (#15, #18). GameStat itself is
# left in place for now: the migration that fills these reads it, and dropping a
# table in the same deploy that stops writing to it leaves nothing to fall back
# on if the counts come out wrong.
class CreateTouchdownsPlaysAndAppearances < ActiveRecord::Migration[8.0]
  def change
    # One try. The assist is a column on the try it produced rather than a row
    # of its own, which is what makes "assists <= tries" impossible to violate
    # by shape. At most one assister: the last pass is the assist.
    #
    # The scorer is nullable in exactly one case — an assist migrated from the
    # old counters whose try was never recorded. A null scorer is therefore its
    # own marker for imported history, and matches no player's try count.
    create_table :touchdowns do |t|
      t.references :fixture, null: false, foreign_key: { deferrable: :deferred }
      t.bigint :scorer_player_id
      t.bigint :assister_player_id

      t.timestamps
    end
    add_index :touchdowns, :scorer_player_id
    add_index :touchdowns, :assister_player_id
    add_foreign_key :touchdowns, :players, column: :scorer_player_id,   deferrable: :deferred
    add_foreign_key :touchdowns, :players, column: :assister_player_id, deferrable: :deferred

    # One stat by one player that is not a try. A row per occurrence, so undoing
    # one is deleting it — and so a player can have five of the same kind in a
    # game without a counter anywhere.
    create_table :plays do |t|
      t.references :fixture, null: false, foreign_key: { deferrable: :deferred }
      t.references :player,  null: false, foreign_key: { deferrable: :deferred }
      t.string :kind, null: false

      t.timestamps
    end
    add_index :plays, [ :fixture_id, :player_id ]

    # The row's existence is the fact: this player took the field. There is no
    # played column, because the sideline toggle inserts and deletes the row.
    create_table :appearances do |t|
      t.references :fixture, null: false, foreign_key: { deferrable: :deferred }
      t.references :player,  null: false, foreign_key: { deferrable: :deferred }

      t.timestamps
    end
    add_index :appearances, [ :fixture_id, :player_id ], unique: true
  end
end
