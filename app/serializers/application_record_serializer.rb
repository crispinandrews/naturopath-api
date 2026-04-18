class ApplicationRecordSerializer
  class << self
    def as_json(record, context: nil)
      attrs = context == :client ? attributes - [ :client_id ] : attributes
      record.as_json(only: attrs).deep_symbolize_keys
    end

    def collection(records, context: nil)
      records.map { |record| as_json(record, context: context) }
    end

    private

    def attributes
      raise NotImplementedError, "#{name} must define .attributes"
    end
  end
end
