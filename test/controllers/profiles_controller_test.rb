require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "shows who you are, what you have reached, and what it earned" do
    sign_in_as users(:member_user)   # linked to Jane
    get profile_path

    assert_response :success
    assert_select "h1", users(:member_user).name
    assert_select ".card-meta", text: /Joined/
    assert_select ".identity .level-number"
    assert_select ".showcase .showcase-slot", Progression::SHOWCASE_SLOTS
    assert_select ".stat-tile-label", text: "Catch rate"
  end

  # Somebody showing their card to a mate should not be looking at their own
  # dropdowns. The slots are a form, and they live behind Customise.
  test "the profile is what you have done, not the controls for saying it" do
    sign_in_as users(:member_user)
    get profile_path

    # the only form on the screen is the layout's own sign-out button
    assert_select "main select", count: 0
    assert_select "main form", count: 0
    assert_select "a[href=?]", profile_slots_path, text: "Customise"
  end

  # Somebody with nothing has to be able to see what there is, or the screen
  # tells them there is nothing to get.
  test "shows what is still to earn, earned or not" do
    sign_in_as users(:member_user)
    get profile_path

    assert_select ".aim", Accolade::LADDERS.size
    assert_select ".aim .rung", Accolade::LADDERS.values.sum(&:size)
    assert_select ".accolade-row.locked", Accolade.repeatable.size
  end

  test "an earned rung is marked on its ladder and drops out of the count" do
    user = users(:member_user)
    user.accolade_awards.create!(key: "appearances_5")
    sign_in_as user
    get profile_path

    assert_select "h2", text: /Still to earn/
    assert_select ".count", text: (Accolade.all.size - 1).to_s
    assert_select ".aim .rung.on", 1
  end

  # The career page and the profile were two screens showing the same person.
  # One screen now: account-wide totals, then a block per roster, because a
  # Season belongs to a Team and cannot be aggregated.
  test "carries the season detail that used to live on the player page" do
    sign_in_as users(:member_user)
    get profile_path

    assert_select "a[href=?]", team_path(teams(:warthogs))      # the roster's own heading
    assert_select ".season-table"
    assert_select ".profile-subheading", text: /By season/
  end

  test "the totals count every team, not the one you happen to be looking at" do
    user = users(:member_user)
    second = Team.create!(name: "Magpies", location: "Ipswich")
    other = second.players.create!(name: "Jane Elsewhere", user: user)
    sign_in_as user
    get profile_path

    line = StatLine.for(user.players.map(&:id))
    assert_select ".stat-tile-value", text: line.games.to_s
    assert_select "h2 .count", text: "all teams"
    assert_select "a[href=?]", team_path(other.team)
  end

  test "requires authentication" do
    get profile_path
    assert_redirected_to new_session_path
  end
end
