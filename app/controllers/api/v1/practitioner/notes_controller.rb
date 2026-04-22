module Api
  module V1
    module Practitioner
      class NotesController < BaseController
        before_action :set_note, only: [ :show, :update, :destroy ]

        def index
          scope = @client.practitioner_notes.order(created_at: :desc)
          records, meta = paginate(scope)
          render_collection(records, serializer: PractitionerNoteSerializer, meta: meta)
        end

        def show
          render_resource(@note, serializer: PractitionerNoteSerializer)
        end

        def create
          note = @client.practitioner_notes.new(note_params.merge(author: @current_practitioner))
          if note.save
            render_resource(note, serializer: PractitionerNoteSerializer, status: :created)
          else
            render_validation_errors(note)
          end
        end

        def update
          if @note.update(note_params)
            render_resource(@note, serializer: PractitionerNoteSerializer)
          else
            render_validation_errors(@note)
          end
        end

        def destroy
          @note.destroy!
          head :no_content
        end

        private

        def set_note
          @note = @client.practitioner_notes.find_by(id: params[:id])
          render_not_found unless @note
        end

        def note_params
          params.permit(:note_type, :body, :pinned)
        end
      end
    end
  end
end
