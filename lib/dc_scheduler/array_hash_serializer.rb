module DcScheduler
  class ArrayHashSerializer
    def self.dump(arr)
      arr.to_json
    end

    def self.load(arr)
      (arr || {}).map &:with_indifferent_access
    end
  end
end