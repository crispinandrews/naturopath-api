module Api
  module V1
    class ClientsController < BaseController
      before_action :authenticate_practitioner!
      before_action :set_client, only: %i[show update destroy resend_invite]

      def index
        clients = @current_practitioner.clients.order(:last_name, :first_name)
        records, meta = paginate(clients)
        render_collection(records, serializer: ClientSerializer, meta: meta)
      end

      def show
        render_resource(@client, serializer: ClientSerializer)
      end

      def create
        client = @current_practitioner.clients.new(client_params)

        if client.save
          deliver_invite_email(client)
          AppEventLogger.info("client.invite_sent", **request_context(client_id: client.id, practitioner_id: @current_practitioner.id))

          render_resource(
            client,
            serializer: ClientSerializerWithInviteToken,
            status: :created
          )
        else
          render_validation_errors(client)
        end
      end

      def update
        if @client.update(client_params)
          render_resource(@client, serializer: ClientSerializer)
        else
          render_validation_errors(@client)
        end
      end

      def destroy
        @client.destroy!
        head :no_content
      end

      def roster_summary
        render json: { data: [] }
      end

      def resend_invite
        @client.refresh_invite!
        deliver_invite_email(@client)
        AppEventLogger.info("client.invite_resent", **request_context(client_id: @client.id, practitioner_id: @current_practitioner.id))

        render_resource(@client, serializer: ClientSerializerWithInviteToken)
      rescue ::Client::InviteAlreadyAcceptedError
        render_error(
          code: "invite_already_accepted",
          message: "Invite has already been accepted",
          status: :unprocessable_entity
        )
      end

      private

      def set_client
        @client = @current_practitioner.clients.find_by(id: params[:id])
        render_not_found unless @client
      end

      def client_params
        params.permit(:email, :first_name, :last_name, :date_of_birth, :focus_tag)
      end

      def deliver_invite_email(client)
        ClientMailer.with(client: client).invite.deliver_later
      end
    end
  end
end
