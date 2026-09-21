class SupportController < ApplicationController
  allow_unauthenticated_access

  def index
    @sections = SECTIONS
  end

  # Grouped Q&A rather than a search box: the whole list is short enough to
  # scan on a phone, and a new user doesn't yet know the vocabulary they'd
  # need to type to find the answer.
  SECTIONS = [
    {
      title: "Getting started",
      questions: [
        {
          q: "How do I set my team up on Touchline?",
          a: "Sign up, then tap “Find your team on TRL” and pick your location, day and competition. " \
             "If your team isn't linked yet, you become its admin and fixtures start syncing automatically. " \
             "If it's already on Touchline, you'll be offered “Request to join” instead."
        },
        {
          q: "I asked to join my team — now what?",
          a: "Your request goes to the team's admin for approval — you'll see “Your join request is pending” " \
             "on the team page until they accept it. There's nothing else to do; you don't need to ask twice."
        },
        {
          q: "I was sent an invite link — what do I do?",
          a: "Open it and tap “Create account & join” (or sign in if you already have an account). " \
             "You're added to the team immediately — no admin approval needed for an invite link. " \
             "If the link named a specific player, your account is linked to their existing stats automatically."
        },
        {
          q: "I signed up but don't see my team yet",
          a: "If you just linked to TRL, fixtures can take a minute to sync — check back shortly. " \
             "If you requested to join an existing team, you're waiting on an admin to approve you."
        }
      ]
    },
    {
      title: "Managing your team (admins)",
      questions: [
        {
          q: "How do I invite my team?",
          a: "Open the gear icon on your Team tab for Team settings. Share the general invite link so anyone can " \
             "ask to join, or use the per-player “Invite” button next to a roster spot you've already " \
             "created — that link connects them straight to their own stats history instead of a blank profile."
        },
        {
          q: "How do I approve someone who asked to join?",
          a: "Team settings → the “Join requests” card at the top of the page. Approve or Decline each " \
             "request there; it's the first thing you see so it's hard to miss."
        },
        {
          q: "How do I make someone an admin, or remove them?",
          a: "Team settings → Members. “Make admin” / “Remove admin” toggles the role; “Kick” " \
             "removes them from the team and unclaims their player, without deleting their stats history."
        }
      ]
    },
    {
      title: "Entering stats",
      questions: [
        {
          q: "How do I record a try or an assist?",
          a: "Tap a player's card for a try on its own. Drag one card onto another to record a try for the card " \
             "you drop on, with an assist for the card you dragged. Press and hold a card for everything else " \
             "— bomb catches, dropped bombs, critical errors, and undoing a mistake."
        },
        {
          q: "How do I scroll the stat entry screen without accidentally recording something?",
          a: "Every card is a tap/drag target, so scrolling from on top of a card can register as a stat. " \
             "Scroll using the narrow strip down the left edge instead — that's where the assist lines are " \
             "drawn and it's always safe to drag on. You can also tap “Lock” above the ladder to freeze " \
             "entry entirely while you scroll, then tap it again to resume."
        },
        {
          q: "I recorded the wrong thing — how do I undo it?",
          a: "Tap Undo right after the mistake to remove the last thing you entered. For anything further back, " \
             "hold the card in question — whatever they already have this game shows up under Remove at the " \
             "bottom of that menu."
        }
      ]
    },
    {
      title: "Your profile",
      questions: [
        {
          q: "How do I link my stats to my account?",
          a: "If your name is already on the roster unclaimed, the Team tab prompts you to tap it the first time " \
             "you visit after joining. An admin can also invite you with a player-specific link that does this " \
             "for you automatically."
        },
        {
          q: "I'm on more than one team — how do I switch?",
          a: "Tap your team's name at the top of the Team tab to open the team switcher, or “My Teams” " \
             "in the account menu."
        }
      ]
    }
  ].freeze
end
