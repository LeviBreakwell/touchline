require "test_helper"

# The landing page: what a signed-out visitor sees before they've signed up
# for anything, and the one page whose copy is a business decision as much as
# a UI one.
class HomeControllerTest < ActionDispatch::IntegrationTest
  test "a signed-out visitor gets the landing page, not the My Teams screen" do
    get root_path

    assert_response :success
    assert_select "a", text: "Sign up"
    assert_no_match(/free/i, response.body)
  end

  test "the landing page sells the new stat set and progression, not just tries" do
    get root_path

    assert_match(/bomb catch/i, response.body)
    assert_match(/dropped bomb/i, response.body)
    assert_match(/xp|level/i, response.body)
  end

  test "a signed-in visitor gets My Teams instead" do
    sign_in_as users(:member_user)

    get root_path

    assert_select "h1", text: "My Teams"
  end
end
