# Verify Team
team = Team.create!(name: "Tally Tigers", location: "Brisbane", subscription_status: :active)
puts "Team created: #{team.name}, Status: #{team.subscription_status}"
raise "Team enum failed" unless team.active?

# Verify User
user = User.create!(email: "player@example.com")
puts "User created: #{user.email}"

# Verify Player
player = Player.create!(first_name: "John", last_name: "Doe", jersey_number: 10, team: team, user: user)
puts "Player created: #{player.first_name}, Team: #{player.team.name}"
raise "Player association failed" unless player.team == team

# Verify Fixture
fixture = Fixture.create!(opponent_name: "Rival Rockets", date: Time.now, team: team)
puts "Fixture created: vs #{fixture.opponent_name}, Played? #{fixture.is_played}"
raise "Fixture default failed" unless fixture.is_played == false
raise "Fixture association failed" unless fixture.team == team

# Verify Stat
stat = Stat.create!(stat_type: :try, player: player, fixture: fixture, game_time: 15)
puts "Stat created: #{stat.stat_type}, Value: #{stat.value}"
raise "Stat enum failed" unless stat.try?
raise "Stat default failed" unless stat.value == 1
raise "Stat association failed" unless stat.player == player && stat.fixture == fixture

puts "ALL VERIFICATIONS PASSED"
