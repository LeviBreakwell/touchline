Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]
  # The slots are a form, and a profile is not: somebody showing their card to
  # a mate should not be looking at their own dropdowns.
  resource :profile, only: %i[show] do
    resource :slots, only: %i[show update], controller: "profile_slots"
  end

  # TRL Australia browser — 3-step wizard to link a team
  scope "/find" do
    get "locations", to: "trl_browser#locations", as: :trl_locations
    get "leagues",   to: "trl_browser#leagues",   as: :trl_leagues
    get "pick",      to: "trl_browser#pick",       as: :trl_pick
  end

  resources :teams, only: %i[new create show] do
    member do
      patch :regenerate_invite
      post  :sync
    end
    # Admin is one screen behind a gear, not a fourth tab: the roster, the
    # invite link, join requests and the Spawtz link all live here.
    resource :settings, only: %i[show], controller: "team_settings"
    resource :spawtz_setup, only: %i[new create]
    resource :membership, only: %i[create destroy], as: :join
    resources :memberships, only: %i[update destroy], controller: "team_memberships"
    resources :players, only: %i[show new create destroy edit update] do
      member { patch :claim }
    end
    resources :seasons, only: %i[show] do
      # The match ladder writes as it goes: one row per gesture, inserted or
      # deleted. There is no sheet to submit.
      resources :fixtures, only: %i[show] do
        # Declared ahead of the resourceful :id routes below, so "latest" is
        # never swallowed as an id. The hold menu's Remove items hit these:
        # a specific row to undo, found by player rather than told an id.
        delete "touchdowns/latest", to: "touchdowns#destroy_latest", as: :latest_touchdown
        delete "plays/latest",      to: "plays#destroy_latest",      as: :latest_play

        resources :touchdowns,  only: %i[create destroy]
        resources :plays,       only: %i[create destroy]
        resources :appearances, only: %i[create destroy], param: :player_id
      end
    end
  end

  get "/join/:invite_token", to: "invitations#show", as: :team_invite

  root "home#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
