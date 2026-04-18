module Api
  module V1
    module Client
      class ConsentsController < BaseController
        def index
          consents = @current_client.consents.order(created_at: :desc)
          records, meta = paginate(consents)
          render_collection(records, serializer: ConsentSerializer, meta: meta)
        end

        def create
          consent = @current_client.consents.new(consent_params)
          consent.granted_at = Time.current
          consent.ip_address = request.remote_ip

          if consent.save
            render_resource(consent, serializer: ConsentSerializer, status: :created)
          else
            render_validation_errors(consent)
          end
        end

        private

        def consent_params
          params.permit(:consent_type, :version)
        end
      end
    end
  end
end
