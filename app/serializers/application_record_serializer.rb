class ApplicationRecordSerializer
  class << self
    def as_json(record)
      record.as_json(only: attributes).deep_symbolize_keys
    end

    def collection(records)
      records.map { |record| as_json(record) }
    end

    private

    def attributes
      raise NotImplementedError, "#{name} must define .attributes"
    end
  end
end
