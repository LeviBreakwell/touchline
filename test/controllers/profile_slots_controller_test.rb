require "test_helper"

# The slots are a form, so they are their own screen — and the screen claiming
# lands on, because picking a title is the useful thing to do with a history
# that has just arrived all at once.
class ProfileSlotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:member_user)
    sign_in_as @user
  end

  # One slot, one source. The border is a rank, so it is not on offer.
  test "the slots offer only what has been earned" do
    user = @user
    user.accolade_awards.create!(key: "tries_5")

    get profile_slots_path

    assert_select "select[name=?] option", "user[title_key]", 2   # "No title" and the one earned
    assert_select "select[name=?] option[value=?]", "user[title_key]", "tries_5"
    assert_select "select[name=?]", "user[border_key]", count: 0
  end

  test "a title nobody earned cannot be worn" do
    user = @user

    patch profile_slots_path, params: { user: { title_key: "tries_100" } }

    assert_nil user.reload.title_key
  end

  test "a title that was earned can be" do
    user = @user
    user.accolade_awards.create!(key: "tries_5")

    patch profile_slots_path, params: { user: { title_key: "tries_5" } }

    assert_equal "tries_5", user.reload.title_key
  end

  test "claiming lands here, with what the history just earned" do
    player = players(:john)
    5.times { fixtures(:played_no_stats).touchdowns.create!(scorer: player) }
    patch claim_team_player_path(teams(:warthogs), player)

    assert_redirected_to profile_slots_path(claimed: player.id)
    follow_redirect!

    assert_select ".claimed-banner", text: /Scorer|accolade|XP/
    assert_select "select[name=?]", "user[title_key]"
  end

  test "requires authentication" do
    delete session_path
    get profile_slots_path

    assert_redirected_to new_session_path
  end
end
