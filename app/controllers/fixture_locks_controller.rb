# Freezing stat entry so a long roster can be scrolled without a touch
# registering as a gesture — see match_ladder_controller#toggleLock. A
# property of the Fixture, not the tab: it has to still be locked for whoever
# opens this screen next, on this phone or another one.
class FixtureLocksController < StatEntriesController
  def update
    @fixture.update!(locked: ActiveModel::Type::Boolean.new.cast(params[:locked]))
    head :no_content
  end
end
