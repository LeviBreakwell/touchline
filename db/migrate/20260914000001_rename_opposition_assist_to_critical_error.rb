# The name never fit what it was pricing: this is not the opposition doing
# something clever, it is the play that let them. Renamed rather than
# re-keyed, so the rows an earlier season already earned stay earned — see
# Accolade, "never revoked".
class RenameOppositionAssistToCriticalError < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE plays SET kind = 'critical_error' WHERE kind = 'opposition_assist'"
    execute <<~SQL
      UPDATE accolade_awards
      SET key = 'critical_errors_' || substring(key FROM 'opposition_assists_(.*)')
      WHERE key LIKE 'opposition_assists_%'
    SQL
  end

  def down
    execute "UPDATE plays SET kind = 'opposition_assist' WHERE kind = 'critical_error'"
    execute <<~SQL
      UPDATE accolade_awards
      SET key = 'opposition_assists_' || substring(key FROM 'critical_errors_(.*)')
      WHERE key LIKE 'critical_errors_%'
    SQL
  end
end
