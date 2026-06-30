Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "health", to: "health#show"

      post "auth/sign_up", to: "auth#sign_up"
      post "auth/login", to: "auth#login"
      get "auth/session", to: "auth#session"
      delete "auth/session", to: "auth#logout"
      get "energy/current", to: "energies#current"

      get "onboarding/status", to: "onboarding#status"
      patch "onboarding/progress", to: "onboarding#progress"
      post "onboarding/complete", to: "onboarding#complete"
      post "onboarding/skip", to: "onboarding#skip"

      resources :tasks, only: %i[index show create update destroy]
      resources :events, only: %i[index show create update destroy] do
        patch :external_origin, on: :member
      end
      get "history", to: "history#index"

      resources :check_ins, only: %i[index create] do
        resources :responses, only: %i[create], module: :check_ins
      end

      post "suggestions/next_action", to: "suggestions#next_action"
      resources :suggestions, only: [] do
        post :actions, on: :member
      end
      resources :interventions, only: %i[index create update]
    end
  end
end
