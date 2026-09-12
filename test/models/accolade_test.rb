require "test_helper"

class AccoladeTest < ActiveSupport::TestCase
  test "six ladders of five rungs, and six repeatables" do
    assert_equal 30, Accolade.all.values.count(&:tiered?)
    assert_equal 6, Accolade.all.values.count(&:repeatable?)
  end

  # A shared ladder cannot work: the same rungs on different stats are wildly
  # different achievements. Twenty bomb catches is eighteen games; twenty
  # opposition assists is two hundred.
  test "every ladder is scaled to its own stat" do
    assert_equal [ 5, 15, 25, 50, 100 ], Accolade.ladder(:tries).map(&:threshold)
    assert_equal [ 1, 2, 3, 10, 15 ], Accolade.ladder(:opposition_assists).map(&:threshold)
    assert_operator Accolade["bomb_catches_150"].threshold, :>, Accolade["opposition_assists_15"].threshold
  end

  test "XP is a fixed tier, never a bespoke number" do
    assert_equal [ 2, 6, 20, 4 ], Accolade::XP.values
    assert Accolade.all.values.all? { |accolade| Accolade::XP.value?(accolade.xp) }
  end

  test "a rung climbs in rarity as it climbs in threshold" do
    ladder = Accolade.ladder(:tries)
    assert_equal %i[common common uncommon uncommon rare], ladder.map(&:rarity)
  end

  # Negatives are genuine accolades, on the same footing as anything else. That
  # is only safe because a Title is chosen, never assigned.
  test "the negative ladders are accolades like any other" do
    assert Accolade["dropped_bombs_2"].tiered?
    assert_equal "Butterfingers", Accolade["dropped_bombs_2"].title
    assert_equal 2, Accolade["dropped_bombs_2"].xp
  end

  test "every accolade has a title somebody would wear, and a glyph to wear it with" do
    Accolade.all.each_value do |accolade|
      assert accolade.title.present?, "#{accolade.key} has no title"
      assert accolade.description.present?, "#{accolade.key} has no description"
      assert Rails.root.join("app/assets/images/accolades/#{accolade.glyph}.svg").exist?,
        "#{accolade.key} points at a glyph that does not exist"
    end
  end

  test "only a rare accolade unlocks a banner" do
    assert Accolade["tries_100"].unlocks_banner?
    assert_not Accolade["tries_5"].unlocks_banner?
  end
end
