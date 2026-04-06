module Api
  module V1
    class ClientsController < BaseController
      before_action :authenticate_practitioner!
      before_action :set_client, only: [ :show, :update, :destroy ]

      def index
        clients = @current_practitioner.clients.order(:last_name, :first_name)
        render json: clients.map { |client| ClientSerializer.as_json(client, include_invite: true) }
      end

      def show
        render json: ClientSerializer.as_json(@client, include_invite: true)
      end

      def create
        client = @current_practitioner.clients.new(client_params)

        if client.save
          render json: ClientSerializer.as_json(client, include_invite: true), status: :created
        else
          render_validation_errors(client)
        end
      end

      def update
        if @client.update(client_params)
          render json: ClientSerializer.as_json(@client, include_invite: true)
        else
          render_validation_errors(@client)
        end
      end

      def destroy
        @client.destroy!
        head :no_content
      end

      private

      def set_client
        @client = @current_practitioner.clients.find_by(id: params[:id])
        render_not_found unless @client
      end

      def client_params
        params.permit(:email, :first_name, :last_name, :date_of_birth)
      end
    end
  end
end
