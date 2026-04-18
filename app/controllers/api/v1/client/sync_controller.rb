module Api
  module V1
    module Client
      class SyncController < BaseController
        InvalidOperation = Class.new(StandardError)

        RESOURCE_CONFIG = {
          "food_entries" => {
            association: :food_entries,
            permitted_attributes: %i[client_uuid meal_type description consumed_at notes],
            serializer: FoodEntrySerializer
          },
          "symptoms" => {
            association: :symptoms,
            permitted_attributes: %i[client_uuid name severity occurred_at duration_minutes notes],
            serializer: SymptomSerializer
          },
          "energy_logs" => {
            association: :energy_logs,
            permitted_attributes: %i[client_uuid level recorded_at notes],
            serializer: EnergyLogSerializer
          },
          "sleep_logs" => {
            association: :sleep_logs,
            permitted_attributes: %i[client_uuid bedtime wake_time quality hours_slept notes],
            serializer: SleepLogSerializer
          },
          "water_intakes" => {
            association: :water_intakes,
            permitted_attributes: %i[client_uuid amount_ml recorded_at],
            serializer: WaterIntakeSerializer
          },
          "supplements" => {
            association: :supplements,
            permitted_attributes: %i[client_uuid name dosage taken_at notes],
            serializer: SupplementSerializer
          }
        }.freeze

        def create
          operations = params.require(:operations)
          return render_invalid_sync_payload unless operations.is_a?(Array)

          results = operations.map.with_index { |operation, index| process_operation(operation, index) }

          AppEventLogger.warn("sync.client_failures", **request_context(client_id: @current_client.id, failed: failed_count(results))) if failed_count(results).positive?

          render json: {
            data: results,
            meta: {
              total: results.size,
              synced: synced_count(results),
              skipped: skipped_count(results),
              failed: failed_count(results)
            }
          }, status: :ok
        end

        private

        def process_operation(raw_operation, index)
          operation = normalize_operation(raw_operation)
          config = RESOURCE_CONFIG[operation[:resource_type]]

          return failure_result(operation, index, "unsupported_resource", "Unsupported resource type") if config.nil?

          case operation[:action]
          when "upsert"
            upsert_resource(operation, config, index)
          when "delete"
            delete_resource(operation, config, index)
          else
            failure_result(operation, index, "unsupported_action", "Unsupported sync action")
          end
        rescue ActiveRecord::RecordNotUnique
          failure_result(operation || {}, index, "duplicate_client_uuid", "Client UUID has already been used")
        rescue InvalidOperation
          failure_result({}, index, "invalid_operation", "Sync operation must be an object")
        end

        def upsert_resource(operation, config, index)
          record = find_existing_record(operation, config)
          return failure_result(operation, index, "record_not_found", "Record not found") if operation[:id].present? && record.nil?

          record ||= resource_scope(config).new
          record.assign_attributes(resource_attributes(operation, config))

          if record.save
            success_result(operation, index, "synced", config[:serializer].as_json(record))
          else
            failure_result(operation, index, "validation_failed", "Validation failed", record.errors.full_messages)
          end
        end

        def delete_resource(operation, config, index)
          record = find_existing_record(operation, config)
          return success_result(operation, index, "skipped", nil) if record.nil?

          serialized_record = record ? config[:serializer].as_json(record) : nil
          record.destroy!

          success_result(operation, index, "deleted", serialized_record)
        end

        def find_existing_record(operation, config)
          scope = resource_scope(config)

          if operation[:id].present?
            record = scope.find_by(id: operation[:id])
            return record if record.present? || operation[:client_uuid].blank?
          end

          return nil if operation[:client_uuid].blank?

          scope.find_by(client_uuid: operation[:client_uuid])
        end

        def resource_scope(config)
          @current_client.public_send(config.fetch(:association))
        end

        def resource_attributes(operation, config)
          attributes = operation.fetch(:attributes, {})
          permitted = config.fetch(:permitted_attributes)
          attributes.slice(*permitted).compact
        end

        def normalize_operation(raw_operation)
          raise InvalidOperation unless raw_operation.respond_to?(:to_h)

          operation = raw_operation.respond_to?(:to_unsafe_h) ? raw_operation.to_unsafe_h : raw_operation.to_h
          operation = operation.deep_symbolize_keys
          attributes = (operation[:attributes] || {}).deep_symbolize_keys
          client_uuid = operation[:client_uuid].presence || attributes[:client_uuid].presence

          {
            op_id: operation[:op_id],
            id: operation[:id],
            resource_type: (operation[:resource_type] || operation[:type]).to_s,
            action: (operation[:action].presence || "upsert").to_s,
            client_uuid: client_uuid,
            attributes: attributes.merge(client_uuid: client_uuid).compact
          }
        end

        def success_result(operation, index, status, record)
          {
            op_id: operation[:op_id],
            index: index,
            id: record&.fetch(:id, nil),
            resource_type: operation[:resource_type],
            client_uuid: operation[:client_uuid],
            status: status,
            record: record
          }
        end

        def failure_result(operation, index, code, message, details = nil)
          {
            op_id: operation[:op_id],
            index: index,
            id: operation[:id],
            resource_type: operation[:resource_type],
            client_uuid: operation[:client_uuid],
            status: "failed",
            error: {
              code: code,
              message: message,
              details: details
            }.compact
          }
        end

        def synced_count(results)
          results.count { |result| %w[synced deleted].include?(result[:status]) }
        end

        def skipped_count(results)
          results.count { |result| result[:status] == "skipped" }
        end

        def failed_count(results)
          results.count { |result| result[:status] == "failed" }
        end

        def render_invalid_sync_payload
          render_error(
            code: "invalid_sync_payload",
            message: "operations must be an array",
            status: :unprocessable_entity
          )
        end
      end
    end
  end
end
