json.extract! stat, :id, :stat_type, :value, :game_time, :player_id, :fixture_id, :created_at, :updated_at
json.url stat_url(stat, format: :json)
