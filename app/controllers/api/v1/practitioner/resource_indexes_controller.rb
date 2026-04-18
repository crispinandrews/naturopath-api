module Api
  module V1
    module Practitioner
      class ResourceIndexesController < BaseController
        def index
          scope = filter_by_date_range(resource_scope, timestamp_column).order(order_column => :desc)
          records, meta = paginate(scope)
          render_collection(records, serializer: serializer_class, meta: meta)
        end

        private

        def order_column
          timestamp_column
        end

        def resource_scope
          raise NotImplementedError, "#{self.class.name} must define #resource_scope"
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
