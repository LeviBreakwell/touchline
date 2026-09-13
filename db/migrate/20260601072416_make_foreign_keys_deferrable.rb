class MakeForeignKeysDeferrable < ActiveRecord::Migration[8.0]
  FK_CONSTRAINTS = [
    { table: "fixtures",         name: "fk_rails_140b10c8ba", col: "season_id",   ref: "seasons(id)" },
    { table: "game_stats",       name: "fk_rails_dfad49c6e7", col: "player_id",   ref: "players(id)" },
    { table: "game_stats",       name: "fk_rails_3e9223f098", col: "fixture_id",  ref: "fixtures(id)" },
    { table: "players",          name: "fk_rails_8880a915a5", col: "team_id",     ref: "teams(id)" },
    { table: "players",          name: "fk_rails_224cac07ce", col: "user_id",     ref: "users(id)" },
    { table: "seasons",          name: "fk_rails_292182df05", col: "team_id",     ref: "teams(id)" },
    { table: "sessions",         name: "fk_rails_758836b4f0", col: "user_id",     ref: "users(id)" },
    { table: "team_memberships", name: "fk_rails_61c29b529e", col: "team_id",     ref: "teams(id)" },
    { table: "team_memberships", name: "fk_rails_5aba9331a7", col: "user_id",     ref: "users(id)" }
  ]

  def up
    FK_CONSTRAINTS.each do |fk|
      execute <<~SQL
        ALTER TABLE #{fk[:table]}
          DROP CONSTRAINT IF EXISTS #{fk[:name]},
          ADD CONSTRAINT #{fk[:name]}
            FOREIGN KEY (#{fk[:col]}) REFERENCES #{fk[:ref]}
            DEFERRABLE INITIALLY DEFERRED;
      SQL
    end
  end

  def down
    FK_CONSTRAINTS.each do |fk|
      execute <<~SQL
        ALTER TABLE #{fk[:table]}
          DROP CONSTRAINT IF EXISTS #{fk[:name]},
          ADD CONSTRAINT #{fk[:name]}
            FOREIGN KEY (#{fk[:col]}) REFERENCES #{fk[:ref]};
      SQL
    end
  end
end
