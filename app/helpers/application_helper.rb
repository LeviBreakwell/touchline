module ApplicationHelper
  BACK_CHEVRON = <<~SVG.html_safe
    <svg width="15" height="15" viewBox="0 0 16 16" fill="none" aria-hidden="true"><path d="M10 3 5 8l5 5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
  SVG

  # The app is used one-handed on a phone, so back is a thumb-sized control
  # rather than a text link.
  def back_button(label, path)
    link_to path, class: "btn-back" do
      BACK_CHEVRON + tag.span(label)
    end
  end

  TRL_STATUS_BADGES = {
    verified:        [ "badge-verified", "TRL VERIFIED" ],
    awaiting_result: [ "badge-pending",  "AWAITING TRL" ],
    over_official:   [ "badge-over",     "OVER TRL" ]
  }.freeze

  # Says where a Fixture's sheet stands against TRL. A Fixture nobody has
  # entered stats for has nothing to verify yet, so it gets no badge.
  def trl_status_badge(fixture)
    return if fixture.game_stats.none?

    css, label = TRL_STATUS_BADGES.fetch(fixture.stats_status)
    tag.span(label, class: "badge #{css}")
  end

  TRY_ICON = <<~SVG.html_safe
    <svg width="11" height="11" viewBox="0 0 16 16" aria-hidden="true"><ellipse cx="8" cy="8" rx="6.4" ry="4.1" fill="currentColor" transform="rotate(-45 8 8)"/></svg>
  SVG

  ASSIST_ICON = <<~SVG.html_safe
    <svg width="11" height="11" viewBox="0 0 16 16" fill="none" aria-hidden="true"><path d="M2.5 8h9M8.5 4.5 12 8l-3.5 3.5" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>
  SVG

  TALLY_ICONS = { tries: [ TRY_ICON, "try" ], assists: [ ASSIST_ICON, "assist" ] }.freeze

  # Past this many, a row of identical glyphs stops being countable at a glance
  # and just wraps the card, so the tally collapses to one icon and a number.
  TALLY_CAP = 6

  # One glyph per try and per assist, so a fixture card can be counted at a
  # glance rather than read as digits. Nothing is rendered at zero — an empty
  # run of icons would put a blank row on the card for every player who did not
  # score. The count is still spelled out for screen readers, which have no use
  # for a picture of six rugby balls.
  def stat_tally(count, kind)
    count = count.to_i
    return if count.zero?

    icon, noun = TALLY_ICONS.fetch(kind)
    label = "#{count} #{noun.pluralize(count)}"

    glyphs = if count > TALLY_CAP
      icon + tag.span("×#{count}", class: "tally-count")
    else
      safe_join(Array.new(count) { icon })
    end

    tag.span(glyphs, class: "tally tally-#{kind}", title: label, aria: { label: label })
  end

  # Two subpaths with fill-rule evenodd, so the inner core is a hole the card
  # shows through rather than a second colour that would have to be kept in
  # step with the background.
  FLAME_ICON = <<~SVG.html_safe
    <svg width="12" height="12" viewBox="0 0 16 16" aria-hidden="true"><path fill-rule="evenodd" d="M8 1.2C10.1 4.6 12.6 6.2 12.6 9.6a4.6 4.6 0 0 1-9.2 0C3.4 6.2 5.9 4.6 8 1.2ZM8 8.5c.8 1.2 1.6 1.8 1.6 2.9a1.6 1.6 0 0 1-3.2 0c0-1.1.8-1.7 1.6-2.9Z" fill="currentColor"/></svg>
  SVG

  MOVE_UP_ICON = <<~SVG.html_safe
    <svg width="8" height="8" viewBox="0 0 16 16" aria-hidden="true"><path d="M8 3.5 13.5 12h-11z" fill="currentColor"/></svg>
  SVG

  MOVE_DOWN_ICON = <<~SVG.html_safe
    <svg width="8" height="8" viewBox="0 0 16 16" aria-hidden="true"><path d="M8 12.5 2.5 4h11z" fill="currentColor"/></svg>
  SVG

  # Marks a Player scoring in their last Leaderboard::HOT_STREAK games or more.
  def hot_streak_flame(row)
    return unless row.hot?

    label = "Scored in #{row.streak} straight games"
    tag.span(FLAME_ICON, class: "flame", title: label, aria: { label: label })
  end

  # Places gained or lost since the game before last. A debut and an unchanged
  # position both read as a dash: "nothing to report" is the honest answer for
  # someone with no previous position, and a board full of NEW on the opening
  # game of a season would say nothing at all. The two still differ on hover.
  def rank_movement(row)
    return tag.span("–", class: "move", title: "First game on this board") if row.new_entry?
    return tag.span("–", class: "move", title: "No change") if row.movement.zero?

    up = row.movement.positive?
    label = "#{up ? 'Up' : 'Down'} #{row.movement.abs}"
    icon = up ? MOVE_UP_ICON : MOVE_DOWN_ICON

    tag.span(icon + row.movement.abs.to_s,
      class: "move move-#{up ? 'up' : 'down'}", title: label, aria: { label: label })
  end

  # The players a fixture card names: whoever actually put something on the
  # board, biggest contribution first and alphabetical within a tie. Filtered
  # and sorted in Ruby because the caller has already preloaded game_stats for
  # the TRL badge — querying here would put one round trip on every card.
  def fixture_scorers(fixture)
    fixture.game_stats
           .select { |stat| stat.tries.to_i.positive? || stat.assists.to_i.positive? }
           .sort_by { |stat| [ -stat.points, stat.player.name ] }
  end
end
