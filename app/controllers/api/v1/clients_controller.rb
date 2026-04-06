module Api
  module V1
    class ClientsController < BaseController
      before_action :authenticate_practitioner!
      before_action :set_client, only: [ :show, :update, :destroy ]

      def index
        clients = @current_practitioner.clients.order(:last_name, :first_name)
        render json: clients.map { |c| client_json(c) }
      end

      def show
        render json: client_json(@client)
      end

      def create
        client = @current_practitioner.clients.new(client_params)

        if client.save
          render json: client_json(client), status: :created
        else
          render_validation_errors(client)
        end
      end

      def update
        if @client.update(client_params)
          render json: client_json(@client)
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

      def client_json(client)
        {
          id: client.id,
          email: client.email,
          first_name: client.first_name,
          last_name: client.last_name,
          date_of_birth: client.date_of_birth,
          invite_token: client.invite_token,
          invite_accepted: client.invite_accepted_at.present?,
          created_at: client.created_at
        }
      end
    end
  end
end
