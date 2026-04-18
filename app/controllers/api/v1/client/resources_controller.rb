module Api
  module V1
    module Client
      class ResourcesController < BaseController
        before_action :set_resource, only: %i[show update destroy]

        def index
          scope = filtered_scope.order(order_column => :desc)
          records, meta = paginate(scope)
          render_collection(records, serializer: serializer_class, meta: meta)
        end

        def show
          render_resource(@resource, serializer: serializer_class)
        end

        def create
          record = resource_scope.new(resource_params)

          if record.save
            render_resource(record, serializer: serializer_class, status: :created)
          else
            render_validation_errors(record)
          end
        end

        def update
          if @resource.update(resource_params)
            render_resource(@resource, serializer: serializer_class)
          else
            render_validation_errors(@resource)
          end
        end

        def destroy
          @resource.destroy!
          head :no_content
        end

        private

        def set_resource
          @resource = resource_scope.find_by(id: params[:id])
          render_not_found unless @resource
        end

        def filtered_scope
          filter_by_date_range(resource_scope, timestamp_column)
        end

        def order_column
          timestamp_column
        end

        def resource_scope
          raise NotImplementedError, "#{self.class.name} must define #resource_scope"
        end

        def resource_params
          raise NotImplementedError, "#{self.class.name} must define #resource_params"
        end

        def serializer_class
          raise NotImplementedError, "#{self.class.name} must define #serializer_class"
        end

        def timestamp_column
          raise NotImplementedError, "#{self.class.name} must define #timestamp_column"
        end
      end
    end
  end
end
