class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    authenticated_owner?
  end

  def show?
    authenticated_owner?
  end

  def create?
    user.present?
  end

  def update?
    authenticated_owner?
  end

  def destroy?
    authenticated_owner?
  end

  private

  def authenticated_owner?
    user.present? && record.respond_to?(:user_id) && record.user_id == user.id
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return @scope.none unless @user
      return @scope.where(user_id: @user.id) if @scope.column_names.include?("user_id")

      @scope.none
    end
  end
end
