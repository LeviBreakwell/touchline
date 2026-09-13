require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Chrome throttles timers and rendering on a page it considers backgrounded
  # or occluded — a heuristic meant for real tabs, applied inconsistently to a
  # headless one with no real window to be in front of or behind. The hold
  # gesture lives entirely on a setTimeout, so a throttled tick reads here as
  # the gesture itself failing rather than as what it is: Chrome being overly
  # helpful about a window nobody is looking at.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_argument("--disable-background-timer-throttling")
    options.add_argument("--disable-backgrounding-occluded-windows")
    options.add_argument("--disable-renderer-backgrounding")
  end

  # Capybara's default 2s wait is tuned for a dev machine. On a shared CI
  # runner a single write's round trip can occasionally outrun it on its own —
  # no eleven-in-a-row required — which reads as a flaky test when it's really
  # just an impatient one. Longer everywhere costs nothing when the thing
  # being waited on lands well inside it, which is the overwhelming case.
  Capybara.default_max_wait_time = 5
end
