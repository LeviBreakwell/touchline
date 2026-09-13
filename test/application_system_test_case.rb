require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Capybara's default 2s wait is tuned for a dev machine. On a shared CI
  # runner a single write's round trip can occasionally outrun it on its own —
  # no eleven-in-a-row required — which reads as a flaky test when it's really
  # just an impatient one. Longer everywhere costs nothing when the thing
  # being waited on lands well inside it, which is the overwhelming case.
  Capybara.default_max_wait_time = 5
end
