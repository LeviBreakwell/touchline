# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_21_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accolade_awards", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "key", null: false
    t.string "subject", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "key", "subject"], name: "index_accolade_awards_on_user_id_and_key_and_subject", unique: true
    t.index ["user_id"], name: "index_accolade_awards_on_user_id"
  end

  create_table "appearances", force: :cascade do |t|
    t.bigint "fixture_id", null: false
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fixture_id", "player_id"], name: "index_appearances_on_fixture_id_and_player_id", unique: true
    t.index ["fixture_id"], name: "index_appearances_on_fixture_id"
    t.index ["player_id"], name: "index_appearances_on_player_id"
  end

  create_table "fixtures", force: :cascade do |t|
    t.string "opponent_name"
    t.datetime "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "season_id", null: false
    t.string "spawtz_fixture_id"
    t.integer "our_score"
    t.integer "opponent_score"
    t.boolean "stats_verified", default: false, null: false
    t.string "finals_label"
    t.boolean "locked", default: false, null: false
    t.index ["season_id"], name: "index_fixtures_on_season_id"
    t.index ["spawtz_fixture_id"], name: "index_fixtures_on_spawtz_fixture_id"
    t.index ["stats_verified"], name: "index_fixtures_on_stats_verified"
  end

  create_table "players", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", null: false
    t.string "email"
    t.index ["email"], name: "index_players_on_email"
    t.index ["team_id"], name: "index_players_on_team_id"
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "plays", force: :cascade do |t|
    t.bigint "fixture_id", null: false
    t.bigint "player_id", null: false
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fixture_id", "player_id"], name: "index_plays_on_fixture_id_and_player_id"
    t.index ["fixture_id"], name: "index_plays_on_fixture_id"
    t.index ["player_id"], name: "index_plays_on_player_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.string "name"
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "spawtz_season_id"
    t.integer "ladder_position"
    t.integer "ladder_size"
    t.index ["team_id"], name: "index_seasons_on_team_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "standings", force: :cascade do |t|
    t.bigint "season_id", null: false
    t.string "spawtz_team_id", null: false
    t.string "team_name", null: false
    t.integer "position", null: false
    t.integer "played"
    t.integer "won"
    t.integer "lost"
    t.integer "drawn"
    t.integer "forfeits_for"
    t.integer "forfeits_against"
    t.integer "points_for"
    t.integer "points_against"
    t.integer "difference"
    t.integer "bonus_points"
    t.integer "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id", "spawtz_team_id"], name: "index_standings_on_season_id_and_spawtz_team_id", unique: true
    t.index ["season_id"], name: "index_standings_on_season_id"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "team_id", null: false
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_team_memberships_on_team_id"
    t.index ["user_id"], name: "index_team_memberships_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "spawtz_venue_id"
    t.string "spawtz_league_id"
    t.string "spawtz_season_id"
    t.string "spawtz_team_id"
    t.string "invite_token"
    t.string "trl_location_slug"
    t.datetime "fixtures_synced_at"
    t.string "spawtz_division_id"
    t.string "division_name"
    t.index ["invite_token"], name: "index_teams_on_invite_token", unique: true
    t.index ["spawtz_division_id"], name: "index_teams_on_spawtz_division_id"
  end

  create_table "touchdowns", force: :cascade do |t|
    t.bigint "fixture_id", null: false
    t.bigint "scorer_player_id"
    t.bigint "assister_player_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assister_player_id"], name: "index_touchdowns_on_assister_player_id"
    t.index ["fixture_id"], name: "index_touchdowns_on_fixture_id"
    t.index ["scorer_player_id"], name: "index_touchdowns_on_scorer_player_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email_address", default: "", null: false
    t.string "password_digest", default: "", null: false
    t.string "name"
    t.string "title_key"
    t.string "banner_key"
    t.string "showcase_keys", default: [], null: false, array: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "accolade_awards", "users", deferrable: :deferred
  add_foreign_key "appearances", "fixtures", deferrable: :deferred
  add_foreign_key "appearances", "players", deferrable: :deferred
  add_foreign_key "fixtures", "seasons", deferrable: :deferred
  add_foreign_key "players", "teams", deferrable: :deferred
  add_foreign_key "players", "users", deferrable: :deferred
  add_foreign_key "plays", "fixtures", deferrable: :deferred
  add_foreign_key "plays", "players", deferrable: :deferred
  add_foreign_key "seasons", "teams", deferrable: :deferred
  add_foreign_key "sessions", "users", deferrable: :deferred
  add_foreign_key "standings", "seasons"
  add_foreign_key "team_memberships", "teams", deferrable: :deferred
  add_foreign_key "team_memberships", "users", deferrable: :deferred
  add_foreign_key "touchdowns", "fixtures", deferrable: :deferred
  add_foreign_key "touchdowns", "players", column: "assister_player_id", deferrable: :deferred
  add_foreign_key "touchdowns", "players", column: "scorer_player_id", deferrable: :deferred
end
