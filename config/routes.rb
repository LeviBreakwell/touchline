Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  # TRL Australia browser — 3-step wizard to link a team
  scope "/find" do
    get "locations", to: "trl_browser#locations", as: :trl_locations
    get "leagues",   to: "trl_browser#leagues",   as: :trl_leagues
    get "pick",      to: "trl_browser#pick",       as: :trl_pick
  end

  resources :teams, only: %i[new create show] do
    member { patch :regenerate_invite }
    resource :spawtz_setup, only: %i[new create]
    resource :membership, only: %i[create destroy]
    resources :memberships, only: %i[index update], controller: "team_memberships"
    resources :players, only: %i[index new create destroy] do
        member { patch :claim }
      end
    resources :seasons, only: %i[show] do
      resources :fixtures, only: %i[show] do
        resources :game_stats, only: %i[create update] do
          collection { post :bulk }
        end
      end
    end
  end

  get "/join/:invite_token", to: "invitations#show", as: :team_invite

  root "home#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
