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

  # Says where a Fixture's record stands against TRL. A Fixture nobody has
  # entered anything for has nothing to verify yet, so it gets no badge.
  def trl_status_badge(fixture)
    return unless fixture.stats_entered?

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

  # Same box as the arrows above, so "no change" sits at the same height as a
  # climb or a fall rather than at wherever a dash character's own glyph
  # happens to sit — a plain "–" text node drifted high against the arrows'
  # baseline, which was the whole row's tell that it wasn't the same kind of
  # thing.
  MOVE_DASH_ICON = <<~SVG.html_safe
    <svg width="8" height="8" viewBox="0 0 16 16" aria-hidden="true"><path d="M3 8h10" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>
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
    return tag.span(MOVE_DASH_ICON, class: "move", title: "First game on this board") if row.new_entry?
    return tag.span(MOVE_DASH_ICON, class: "move", title: "No change") if row.movement.zero?

    up = row.movement.positive?
    label = "#{up ? 'Up' : 'Down'} #{row.movement.abs}"
    icon = up ? MOVE_UP_ICON : MOVE_DOWN_ICON

    tag.span(icon + row.movement.abs.to_s,
      class: "move move-#{up ? 'up' : 'down'}", title: label, aria: { label: label })
  end

  Scorer = Struct.new(:player, :tries, :assists) do
    def points = (tries * Touchdown::TRY_POINTS) + (assists * Touchdown::ASSIST_POINTS)
  end

  # The players a fixture card names: whoever actually put something on the
  # board, biggest contribution first and alphabetical within a tie. Counted in
  # Ruby off rows the caller has already preloaded for the TRL badge, against a
  # roster it looked up once — querying here would put a round trip on every
  # card. An imported assist names nobody as scorer, so it lands under its
  # assister and nowhere else.
  def fixture_scorers(fixture, players_by_id)
    tallies = Hash.new { |hash, player_id| hash[player_id] = Scorer.new(players_by_id[player_id], 0, 0) }

    fixture.touchdowns.each do |touchdown|
      tallies[touchdown.scorer_player_id].tries += 1 if touchdown.scorer_player_id
      tallies[touchdown.assister_player_id].assists += 1 if touchdown.assister_player_id
    end

    tallies.values.select(&:player).sort_by { |scorer| [ -scorer.points, scorer.player.name ] }
  end

  GEAR_ICON = <<~SVG.html_safe
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z" stroke="currentColor" stroke-width="2"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9c.2.5.68.86 1.23.9H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1Z" stroke="currentColor" stroke-width="1.6"/></svg>
  SVG

  CHEVRON_DOWN = <<~SVG.html_safe
    <svg width="14" height="14" viewBox="0 0 16 16" fill="none" aria-hidden="true"><path d="m4 6 4 4 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
  SVG

  def gear_icon = GEAR_ICON
  def chevron_down = CHEVRON_DOWN

  FORM_UP   = %(<svg width="10" height="10" viewBox="0 0 16 16" aria-hidden="true"><path d="M8 3 14 12H2z" fill="currentColor"/></svg>).html_safe
  FORM_DOWN = %(<svg width="10" height="10" viewBox="0 0 16 16" aria-hidden="true"><path d="M8 13 2 4h12z" fill="currentColor"/></svg>).html_safe
  FORM_LEVEL = %(<svg width="10" height="10" viewBox="0 0 16 16" aria-hidden="true"><path d="M3 8h10" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/></svg>).html_safe

  # This season against the rest of a career: an arrow, a colour, and nothing
  # else. Green and red are what the arrow means for this stat rather than
  # which way it points — a rising drop count is a falling player.
  #
  # Too few games either side and the marker says so in its own way, because an
  # arrow that is simply absent reads as "level".
  def form_arrow(reading)
    return tag.span(FORM_LEVEL, class: "form form-unknown", title: "Not enough games either side to tell yet") unless reading.certain?

    icon, label = case reading.direction
    when :up   then [ FORM_UP, "Up on career" ]
    when :down then [ FORM_DOWN, "Down on career" ]
    else            [ FORM_LEVEL, "Level with career" ]
    end

    css = reading.level? ? "form-level" : (reading.good? ? "form-good" : "form-bad")
    tag.span(icon, class: "form #{css}", title: label, aria: { label: label })
  end

  # A border is a shape masked over a metal gradient. The shape is the file and
  # the metal is a class, which is how four pieces of art are twelve tiers —
  # see ADR 0005.
  def border_ring(tier)
    return if tier.nil?

    tag.span(nil, class: "border-ring metal-#{tier.metal}",
                  style: mask_of("borders/#{tier.shape}.svg"),
                  aria: { hidden: true }, title: tier.name)
  end

  def accolade_glyph(accolade, size: nil)
    tag.span(nil, class: "accolade-glyph", style: [ mask_of("accolades/#{accolade.glyph}.svg"), size ].compact.join(";"),
                  aria: { hidden: true })
  end

  def mask_of(asset)
    url = image_path(asset)
    "-webkit-mask-image:url(#{url});mask-image:url(#{url})"
  end

  # One glyph per tab. Drawn rather than borrowed: three shapes at 20px is not
  # worth a dependency, and each is a single path.
  TAB_ICONS = {
    team:    %(<path d="M3 13h3v6H3zM10.5 8h3v11h-3zM18 4h3v15h-3z" fill="currentColor"/>),
    season:  %(<path d="M4 6h16v14H4zM4 10h16M8 3v4M16 3v4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>),
    profile: %(<path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM4.5 20a7.5 7.5 0 0 1 15 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>)
  }.freeze

  def tab_icon(tab)
    tag.svg(TAB_ICONS.fetch(tab).html_safe, width: 20, height: 20, viewBox: "0 0 24 24", aria: { hidden: true })
  end

  # Two letters is what fits inside a 38px disc, and a first name plus a
  # surname is what a roster holds.
  def player_initials(player)
    player.name.split.first(2).map { |part| part[0] }.join.upcase
  end
end
