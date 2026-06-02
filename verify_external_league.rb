# Verify ExternalLeague
team = Team.first || Team.create!(name: "Test Team", location: "Test Loc", subscription_status: :active)

external_league = ExternalLeague.create!(
  name: "Spawtz League A",
  spawtz_venue_id: "v123",
  spawtz_league_id: "l456",
  spawtz_season_id: "s789",
  team: team
)

puts "ExternalLeague created: #{external_league.name}"
puts "Associated Team: #{external_league.team.name}"

team.reload
puts "Team has ExternalLeague: #{team.external_league.name}"

raise "Association failed" unless team.external_league == external_league
puts "VERIFICATION PASSED"
