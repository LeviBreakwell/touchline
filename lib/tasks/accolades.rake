namespace :accolades do
  # Awarding is additive and safe to repeat — see AccoladeLedger, "never
  # revoked" — but nothing ever re-scans a User's whole history on its own.
  # #settle runs once, at claim, and after that only a fixture's own recent
  # window gets rechecked (SettleAccoladesJob). Adding a new accolade to the
  # catalogue after that point earns it for new games, never for the seasons
  # already sitting on the ledger, until this is run once by hand.
  desc "Re-settle every User's whole history — run once after adding a new accolade"
  task backfill: :environment do
    count = User.count
    User.find_each.with_index(1) do |user, index|
      AccoladeLedger.settle(user)
      print "\r#{index}/#{count}"
    end
    puts
  end
end
