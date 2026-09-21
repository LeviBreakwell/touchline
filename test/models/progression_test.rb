require "test_helper"

# John: 8 tries, 5 assists, 3 games across two seasons. No Plays in the shared
# data, so everything here adds its own.
class ProgressionTest < ActiveSupport::TestCase
  setup do
    @user = users(:member_user)
    @player = players(:jane)     # 1 game, nothing else
  end

  def progression = Progression.new(@user.reload)

  test "XP is ten a game plus one a stat, whatever the stat was" do
    # Jane: one appearance, nothing recorded
    assert_equal 10, progression.xp

    fixtures(:summer_final).touchdowns.create!(scorer: @player)
    assert_equal 11, progression.xp

    fixtures(:summer_final).plays.create!(player: @player, kind: :dropped_bomb)
    assert_equal 12, progression.xp, "a dropped bomb earns the same XP as a try, and still costs 2 points"
  end

  # A try with a pass is one row and two stats: the scorer is credited and so
  # is whoever put them through.
  test "an assist earns the assister XP as well as the scorer" do
    fixtures(:summer_final).touchdowns.create!(scorer: players(:john), assister: @player)

    assert_equal 11, progression.xp
  end

  test "accolades pay their tier on top" do
    @user.accolade_awards.create!(key: "tries_5")     # common, 2
    @user.accolade_awards.create!(key: "tries_100")   # rare, 20

    assert_equal 32, progression.xp
  end

  # Points measure performance; XP measures participation. That split is the
  # whole reason there are two currencies.
  test "turning up outruns anybody's best single game" do
    quiet = 10                                    # an appearance and nothing else
    enormous = 10 + 5 + 20                        # five stats and a rare accolade

    assert_operator quiet * 4, :>, enormous, "four quiet games should beat one enormous one"
  end

  test "level and border follow from XP alone" do
    assert_equal 1, progression.level
    assert_equal "bronze circle", progression.border.name

    # 45 rungs at 2 XP each, on top of the 10 for the appearance
    45.times { |i| @user.accolade_awards.create!(key: "tries_5", subject: "fixture:#{i}") }

    assert_equal 100, progression.xp
    assert_equal 6, progression.level
    assert_equal "gold circle", progression.border.name
  end

  test "a repeatable carries its count rather than a row on the profile" do
    3.times { |i| @user.accolade_awards.create!(key: "mvp", subject: "fixture:#{i}") }

    assert_equal 1, progression.earned.size
    assert_equal 3, progression.count_of("mvp")
    assert_equal 12, progression.accolade_xp
  end

  test "the showcase holds three, and only what was earned" do
    @user.accolade_awards.create!(key: "tries_5")
    @user.update!(showcase_keys: %w[tries_5 tries_100 nonsense])

    assert_equal [ "Scorer" ], progression.showcase.map(&:title)
  end

  test "an unclaimed history earns nobody anything" do
    assert_equal 0, Progression.new(users(:stranger)).xp
    assert_nil Progression.new(users(:stranger)).border
  end

  # A profile that lists only what has been earned tells somebody with nothing
  # that there is nothing to get.
  test "every accolade is still to earn when nothing has been" do
    assert_equal Accolade.all.size, progression.left_to_earn
    assert_equal 6, progression.unearned_one_offs.size
  end

  test "a ladder reports the next rung and the distance to it" do
    3.times { fixtures(:summer_final).touchdowns.create!(scorer: @player) }

    tries = progression.climbs.find { |climb| climb.stat == :tries }

    assert_equal 3, tries.total
    assert_equal "Scorer", tries.next_rung.title
    assert_equal 2, tries.to_go
    assert_in_delta 0.6, tries.fraction, 0.01
  end

  # Measured from the rung below rather than from zero, so a nearly-full bar
  # means nearly there.
  test "the distance to a rung is measured from the rung below it" do
    @user.accolade_awards.create!(key: "tries_5")
    5.times { fixtures(:summer_final).touchdowns.create!(scorer: @player) }

    tries = progression.climbs.find { |climb| climb.stat == :tries }

    assert_equal "Finisher", tries.next_rung.title
    assert_equal 10, tries.to_go
    assert_in_delta 0.0, tries.fraction, 0.01, "five tries is the bottom of the rung, not half way up it"
  end

  test "a finished ladder says so rather than pointing at a rung that is not there" do
    Accolade.ladder(:tries).each { |rung| @user.accolade_awards.create!(key: rung.key) }

    tries = progression.climbs.find { |climb| climb.stat == :tries }

    assert_predicate tries, :complete?
    assert_nil tries.next_rung
    assert_equal 0, tries.to_go
    assert_in_delta 1.0, tries.fraction, 0.01
  end

  # A rung is never revoked, so a total can sit below one already earned.
  test "a total that went backwards does not push a bar below empty" do
    @user.accolade_awards.create!(key: "tries_5")   # earned, then the sheet was fixed

    tries = progression.climbs.find { |climb| climb.stat == :tries }

    assert_equal 0, tries.total
    assert_equal "Finisher", tries.next_rung.title
    assert_in_delta 0.0, tries.fraction, 0.01
  end

  # ── FINALS ────────────────────────────────────────────────────────────────

  test "a grand final pays double on the appearance and every stat" do
    fixtures(:summer_final).update!(finals_label: "Grand Final")

    assert_equal 20, progression.xp, "Jane's one appearance was in the Grand Final"

    fixtures(:summer_final).touchdowns.create!(scorer: @player)
    assert_equal 22, progression.xp, "the try itself is worth double too"
  end

  test "a preliminary final pays the same boost as the Grand Final" do
    fixtures(:summer_final).update!(finals_label: "Preliminary Final")

    assert_equal 20, progression.xp
  end

  test "a semi does not pay the finals boost" do
    fixtures(:summer_final).update!(finals_label: "Semi Final 1")

    assert_equal 10, progression.xp, "only a preliminary or grand final is worth more"
  end

  test "an ordinary round is untouched by the finals boost" do
    assert_equal 10, progression.xp
  end

  test "the batch says the same thing as asking one at a time, finals boost included" do
    fixtures(:summer_final).update!(finals_label: "Grand Final")
    batched = Progression.batch([ @user.id ])

    assert_equal progression.xp, batched[@user.id].xp
  end

  test "the batch says the same thing as asking one at a time" do
    @user.accolade_awards.create!(key: "tries_5")
    batched = Progression.batch([ @user.id, users(:admin_user).id ])

    assert_equal progression.xp, batched[@user.id].xp
    assert_equal progression.level, batched[@user.id].level
  end
end
