# Accolades are awarded, not computed, so something has to do the awarding.
# Games are given time to be entered first — see AccoladeLedger#settle_fixture.
class SettleAccoladesJob < ApplicationJob
  queue_as :default

  def perform
    AccoladeLedger.settle_recent
  end
end
