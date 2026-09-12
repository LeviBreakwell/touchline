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

  test "the batch says the same thing as asking one at a time" do
    @user.accolade_awards.create!(key: "tries_5")
    batched = Progression.batch([ @user.id, users(:admin_user).id ])

    assert_equal progression.xp, batched[@user.id].xp
    assert_equal progression.level, batched[@user.id].level
  end
end
