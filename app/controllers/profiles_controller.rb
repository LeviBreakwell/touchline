class ProfilesController < ApplicationController
  def current_tab = :profile

  def show
    @user = Current.user
    @players = @user.players.includes(:team).order("teams.name")

    # The account-scoped half: a User is one person, so every roster they are on
    # counts towards one set of totals, one level and one set of accolades.
    @line = StatLine.for(@players.map(&:id))
    @progression = Progression.new(@user, line: @line)

    # The team-scoped half, one block per roster. A Season belongs to a Team, so
    # "this season" and "by season" can only be asked a team at a time — which
    # is why this is a list rather than one more aggregate. Being on two at once
    # is rare, so they stack rather than hiding behind a control.
    #
    # Busiest first, because on the rare two-roster profile the one you are
    # actually playing for is the one you came to read — and a roster you have
    # never taken the field for should not be the first thing under Career.
    @careers = @players.map { |player| Career.new(player) }
                       .sort_by { |career| [ -career.line.games, career.team.name ] }
  end
end
