# Everything one Team's settings screen shows, in one place.
#
# The screen exists because the map allows exactly three tabs and admin work is
# not one of them: the roster, the invite link, join requests and the Spawtz
# link all live behind a gear rather than competing for a tab of their own.
class TeamSettings
  def initialize(team)
    @team = team
  end

  # The roster is not the leaderboard. Only Players with an appearance are
  # ranked, so a signing who has not played yet is invisible everywhere else.
  def roster = @team.players.order(:name)

  def pending  = @team.team_memberships.pending.includes(:user)
  def accepted = @team.team_memberships.accepted.includes(:user)

  def linked_to_spawtz? = @team.linked_to_spawtz?

  def last_synced = @team.fixtures_synced_at
end
