require "application_system_test_case"

# The stepper enforces TRL's ceiling in the browser so a Member never builds a
# sheet the server is only going to reject. The rules themselves live in
# StatSheet and GameStat — these cover the stepper that fronts them.
class StatEntryTest < ApplicationSystemTestCase
  setup do
    @team    = teams(:warthogs)
    @season  = seasons(:winter_2026)
    @fixture = fixtures(:played_with_stats)   # TRL has this at 5
    sign_in_as users(:member_user)
  end

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    # Wait for the session to actually land, or the next visit races it and
    # renders as a signed-out visitor.
    assert_selector "details.user-menu"
  end

  def open_sheet
    visit team_season_fixture_path(@team, @season, @fixture)
  end

  def row_for(player)
    find(".stat-row", text: player.name)
  end

  def plus(player, field)
    row_for(player).find(".stepper-btn[data-field='#{field}']", text: "+")
  end

  def minus(player, field)
    row_for(player).find(".stepper-btn[data-field='#{field}']", text: "−")
  end

  def value(player, field)
    row_for(player).find("[data-display='#{field}']").text.to_i
  end

  test "the stepper stops at TRL's published try count" do
    open_sheet
    # John already has 3 of TRL's 5; spend the last two, then try for a sixth.
    4.times { plus(players(:john), :tries).click }

    assert_equal 5, value(players(:john), :tries)
    assert_text "5/5T"
  end

  test "a refused increment says so rather than doing nothing" do
    open_sheet
    4.times { plus(players(:john), :tries).click }
    plus(players(:john), :tries).click

    assert_selector ".stepper--refused"
    assert_selector ".stat-hint--refused"
  end

  test "the allowance is shared across the roster, not per player" do
    open_sheet
    2.times { plus(players(:john), :tries).click }   # team now on TRL's 5

    plus(players(:jane), :tries).click

    assert_equal 0, value(players(:jane), :tries)
    assert_text "5/5T"
  end

  test "the plus buttons dim once the allowance is spent" do
    open_sheet
    2.times { plus(players(:john), :tries).click }

    assert_selector ".stepper-btn--spent"
  end

  test "giving a try back frees exactly one for someone else" do
    open_sheet
    2.times { plus(players(:john), :tries).click }
    minus(players(:john), :tries).click

    plus(players(:jane), :tries).click
    assert_equal 1, value(players(:jane), :tries)

    plus(players(:jane), :tries).click
    assert_equal 1, value(players(:jane), :tries)
  end

  test "assists carry their own allowance" do
    open_sheet
    2.times { plus(players(:john), :tries).click }   # tries spent

    plus(players(:john), :assists).click
    assert_equal 2, value(players(:john), :assists)
  end

  test "the running total sits directly above the roster" do
    open_sheet

    assert page.evaluate_script(<<~JS), "the total bar should be the roster's immediate previous sibling"
      document.querySelector(".stat-total-bar").nextElementSibling
        .contains(document.querySelector(".stat-row"))
    JS
  end

  test "the running total stays pinned under the header while the roster scrolls" do
    8.times { |i| @team.players.create!(name: "Sub #{i}") }
    page.driver.browser.manage.window.resize_to(420, 700)   # a phone, where this matters
    open_sheet

    page.execute_script("window.scrollTo(0, 600)")
    assert page.evaluate_script("window.scrollY") > 100, "the roster needs to be long enough to scroll"

    header_bottom = page.evaluate_script("Math.round(document.querySelector('.site-header').getBoundingClientRect().bottom)")
    bar_top       = page.evaluate_script("Math.round(document.querySelector('.stat-total-bar').getBoundingClientRect().top)")

    assert_equal header_bottom, bar_top, "the total bar should sit flush under the header once stuck"
  end

  test "the pinned total keeps counting as rows further down change" do
    8.times { |i| @team.players.create!(name: "Sub #{i}") }
    page.driver.browser.manage.window.resize_to(420, 700)
    open_sheet

    page.execute_script("window.scrollTo(0, 600)")
    plus(players(:john), :assists).click

    assert_text "2/5A"
  end
end
