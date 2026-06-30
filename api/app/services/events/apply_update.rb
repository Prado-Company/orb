module Events
  class ApplyUpdate
    def initialize(event)
      @event = event
    end

    def call(changes)
      @event.update!(changes)
      @event
    end
  end
end
