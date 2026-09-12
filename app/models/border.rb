# The icon border: a rank, not a decoration.
#
# It is automatic and always the highest tier reached, because it has to mean
# the same thing on every card for everybody. Border is what you *are*; title
# is what you choose to say about it.
#
# It climbs by shape as well as colour, because colour alone runs out after
# about four distinguishable steps. Four pieces of art become twelve tiers,
# spanning one game to about three hundred.
module Border
  Tier = Struct.new(:shape, :metal, :level, keyword_init: true) do
    def name = "#{metal} #{shape}"
  end

  LADDER = [
    [ "circle",  1 ], [ "circle",  3 ], [ "circle",  6 ],
    [ "shield",  10 ], [ "shield",  14 ], [ "shield",  19 ],
    [ "octagon", 24 ], [ "octagon", 30 ], [ "octagon", 36 ],
    [ "star",    43 ], [ "star",    50 ], [ "star",    58 ]
  ].each_with_index.map { |(shape, level), index|
    Tier.new(shape: shape, metal: %w[bronze silver gold][index % 3], level: level)
  }.freeze

  # Nil below level 1: an unclaimed roster entry and a brand new account both
  # carry no cosmetics at all, and the card says so.
  def self.for(level) = LADDER.reverse.find { |tier| level >= tier.level }

  def self.next_after(level) = LADDER.find { |tier| level < tier.level }
end
