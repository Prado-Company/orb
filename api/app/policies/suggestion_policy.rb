class SuggestionPolicy < ApplicationPolicy
  def next_action?
    authenticated_owner?
  end
end
