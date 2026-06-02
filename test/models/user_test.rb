require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup { @team = teams(:warthogs) }

  test "admin_of? is true for admin member" do
    assert users(:admin_user).admin_of?(@team)
  end

  test "admin_of? is false for plain member" do
    assert_not users(:member_user).admin_of?(@team)
  end

  test "admin_of? is false for non-member" do
    assert_not users(:stranger).admin_of?(@team)
  end

  test "member_of? is true for accepted admin" do
    assert users(:admin_user).member_of?(@team)
  end

  test "member_of? is true for accepted member" do
    assert users(:member_user).member_of?(@team)
  end

  test "member_of? is false for non-member" do
    assert_not users(:stranger).member_of?(@team)
  end
end
