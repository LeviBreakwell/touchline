require "application_system_test_case"

# The gestures, in a real browser. Every one of them writes a row as it goes:
# there is no sheet and no submit, so what is on screen after a gesture is what
# the server sent back.
class StatEntryTest < ApplicationSystemTestCase
  setup do
    @team    = teams(:warthogs)
    @season  = seasons(:winter_2026)
    @fixture = fixtures(:played_no_stats)   # TRL has this at 10, nothing entered
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

  def open_ladder
    visit team_season_fixture_path(@team, @season, @fixture)
    assert_selector ".ladder--editable"
  end

  def card_for(player) = find(".lcard[data-player-id='#{player.id}']")

  def tally(player, column) = card_for(player).find(".lchip.#{column}").text.to_i

  # The ladder writes as it goes, so the screen settling and the rows landing
  # are two different observations. Capybara waits for the first; this waits
  # for the second. A write that never lands still fails the test.
  def eventually(timeout: 3)
    deadline = Time.now + timeout
    loop do
      return if yield
      flunk "timed out waiting for the write to land" if Time.now > deadline
      sleep 0.05
    end
  end

  def hold(player, ms: 600)
    element = card_for(player)
    page.driver.browser.action.click_and_hold(element.native).perform
    sleep ms / 1000.0
  end

  test "a tap is a try" do
    open_ladder

    card_for(players(:john)).click

    assert_text "John — try +2"
    assert_equal 1, tally(players(:john), :t)
    assert_equal 1, @fixture.entered_tries
  end

  test "the try lands on the board, not just on the card" do
    open_ladder
    card_for(players(:john)).click

    assert_selector ".lcard[data-player-id='#{players(:john).id}'] .lcard-pts", text: "+2"
  end

  test "the ladder re-sorts as stats land" do
    open_ladder
    # Jane is first alphabetically and so first while nobody has scored
    assert_equal players(:jane).id.to_s, all(".lcard").first["data-player-id"]

    card_for(players(:john)).click

    assert_text "John — try +2"
    assert_equal players(:john).id.to_s, all(".lcard").first["data-player-id"]
  end

  # Read straight off the ring: the fill is the only thing that says how much
  # of the hold is left, and it was wrong in two ways at once.
  def ring_measure
    page.evaluate_script(<<~JS)
      (() => {
        const ring = document.querySelector(".hold-ring");
        if (!ring) return null;
        const r = ring.getBoundingClientRect(), icon = ring.parentElement.getBoundingClientRect();
        return {
          offset: parseFloat(getComputedStyle(ring.querySelector("circle")).strokeDashoffset),
          dx: Math.round((r.x + r.width / 2) - (icon.x + icon.width / 2)),
          dy: Math.round((r.y + r.height / 2) - (icon.y + icon.height / 2))
        };
      })()
    JS
  end

  # Both halves of this were wrong once. An inset ring measures from inside the
  # icon's own border, so it sat 2px off it; and a transition started a frame
  # after the ring lands has nothing to transition from if that frame beats the
  # first committed style, so the ring came up already full instead of filling.
  test "the hold ring fills, centred on the icon" do
    open_ladder
    page.driver.browser.action.click_and_hold(card_for(players(:john)).native).perform

    begin
      sleep 0.08
      early = ring_measure
      sleep 0.16
      later = ring_measure

      assert early, "the ring should be up while the finger is down"
      assert_equal [ 0, 0 ], [ early["dx"], early["dy"] ], "the ring should be centred on the icon"
      assert_operator early["offset"], :>, 0, "the ring should still be filling this early in the hold"
      assert_operator later["offset"], :<, early["offset"], "the ring should fill as the hold goes on"
    ensure
      page.driver.browser.action.release.perform
    end
  end

  test "a hold opens the play menu" do
    open_ladder
    hold(players(:john))

    assert_selector ".play-menu"
    assert_text "Bomb catch"
    assert_text "Dropped bomb"
    assert_text "Opposition assist"
  end

  test "picking a play from the menu records it" do
    open_ladder
    hold(players(:john))
    page.driver.browser.action.release.perform
    click_on "Dropped bomb"

    assert_text "John — dropped bomb"
    assert_equal 1, tally(players(:john), :e)
    assert_equal 1, @fixture.plays.count
  end

  test "a packed menu stays on screen and reachable on a short viewport" do
    # Give John every kind at least once, so the menu grows a full Remove
    # section on top of the usual items — as tall as this menu ever gets.
    @fixture.touchdowns.create!(scorer: players(:john), assister: players(:jane))
    @fixture.touchdowns.create!(scorer: players(:jane), assister: players(:john))
    @fixture.plays.create!(player: players(:john), kind: "bomb_catch")
    @fixture.plays.create!(player: players(:john), kind: "dropped_bomb")
    @fixture.plays.create!(player: players(:john), kind: "opposition_assist")

    open_ladder
    page.driver.browser.manage.window.resize_to(390, 320)   # a short phone in landscape
    # The resize is asynchronous in some browsers — proceeding before the
    # viewport has actually caught up means the hold lands on a card that
    # isn't where the layout will settle, and the menu never opens.
    eventually { page.evaluate_script("window.innerWidth") <= 400 }
    hold(players(:john))

    assert_selector ".play-menu button.destructive", count: 5, minimum: 5

    fits = page.evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector(".play-menu").getBoundingClientRect();
        return r.top >= 0 && r.left >= 0 && r.bottom <= window.innerHeight && r.right <= window.innerWidth;
      })()
    JS
    assert fits, "the menu should fit entirely inside the viewport, scrolling internally if it has to"

    page.driver.browser.action.release.perform
  end

  test "a card with nothing on it yet offers nothing to remove" do
    open_ladder
    hold(players(:john))

    assert_selector ".play-menu"
    assert_no_selector ".play-menu button.destructive"
  end

  test "removing a try from the hold menu takes it back off the ladder" do
    open_ladder
    card_for(players(:john)).click
    assert_selector ".lcard[data-player-id='#{players(:john).id}'] .lchip.t", text: "1"

    hold(players(:john))
    assert_selector ".play-menu button.destructive", text: "Remove a try"
    page.driver.browser.action.release.perform
    click_on "Remove a try"

    assert_text "Undone"
    assert_equal 0, tally(players(:john), :t)
    eventually { @fixture.entered_tries.zero? }
  end

  test "the sideline is a menu item, and it takes them off the grass" do
    open_ladder
    hold(players(:jane))
    page.driver.browser.action.release.perform
    click_on "Didn't play"

    assert_selector ".ladder-sideline"
    assert_selector ".lcard.sidelined[data-player-id='#{players(:jane).id}']"
    assert_not @fixture.appearances.exists?(player_id: players(:jane).id)
  end

  test "tapping a sidelined card brings them back on" do
    @fixture.open_sideline!
    @fixture.appearances.find_by(player_id: players(:jane).id).destroy!
    open_ladder

    card_for(players(:jane)).click

    assert_text "Jane — played"
    assert_no_selector ".lcard.sidelined"
  end

  test "undo takes the last row back off" do
    open_ladder
    card_for(players(:john)).click
    # wait for the write to land before reading anything off the DOM
    assert_selector ".lcard[data-player-id='#{players(:john).id}'] .lchip.t", text: "1"

    click_on "Undo"

    assert_text "Undone"
    assert_equal 0, tally(players(:john), :t)
    eventually { @fixture.entered_tries.zero? }
  end

  test "there is nothing to undo until something has been entered" do
    open_ladder

    assert_no_selector "button", text: "Undo"
  end

  # Going past TRL's published score is recorded and flagged, never refused —
  # the refusal could only ever have fired on a game TRL had already scored.
  test "the eleventh try in a game TRL scored 10 is still recorded" do
    open_ladder
    11.times { card_for(players(:john)).click }

    # Eleven queued writes is the heaviest single test in this file — on a
    # loaded runner the round trips alone can outrun a default wait, so check
    # the authoritative model state first, with a generous timeout, then give
    # the DOM the same patience rather than a one-shot assertion: the eleventh
    # response can commit its write a beat before the browser has rendered it.
    eventually(timeout: 15) { @fixture.entered_tries == 11 }
    eventually(timeout: 15) { tally(players(:john), :t) == 11 }

    assert_equal 11, @fixture.entered_tries
    assert_equal :over_official, @fixture.reload.stats_status
  end
end
