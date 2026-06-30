module Api
  module V1
    class FoundationController < BaseController
      def not_implemented
        render_error(
          code: "feature_not_implemented",
          message: "Contrato criado; implementacao de dominio entra no sprint planejado.",
          status: :not_implemented,
          details: { source: @request_source }
        )
      end
    end
  end
end
