# A User's standing, derived from XP.
#
# Each level costs 2 XP more than the last — cost(n) = 10 + 2(n − 1) — so the
# XP to reach level L is L(L + 9). Broadly it reads as how much football
# somebody has turned up to: level 4 is four games, 10 is fifteen, 20 is
# forty-six, 40 is a hundred and fifty-seven.
#
# Never expressed in seasons. A season's length depends on how many teams are
# in the competition, anywhere from about five games to about twenty-six, so a
# milestone quoted in seasons would mean something different in every league.
module Level
  FIRST_COST = 10
  STEP = 2

  # The inverse of xp_for: the largest L where L(L + 9) <= xp.
  def self.for(xp)
    return 0 if xp.to_i < FIRST_COST
    ((-9 + Math.sqrt(81 + (4 * xp))) / 2).floor
  end

  def self.xp_for(level) = level * (level + 9)

  def self.cost_of(level) = FIRST_COST + (STEP * (level - 1))

  # How far through the current level somebody is, as [earned, needed].
  def self.progress(xp)
    level = self.for(xp)
    [ xp - xp_for(level), cost_of(level + 1) ]
  end
end
