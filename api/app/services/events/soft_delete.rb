module Events
  class SoftDelete
    def initialize(event)
      @event = event
    end

    def call
      @event.update!(
        title: "Evento excluido",
        category: nil,
        external_ref: nil,
        deleted_at: Time.current
      )
      @event
    end
  end
end
