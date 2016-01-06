unless Hash.respond_to?(:deep_dup)
  class Hash
    def deep_dup
      duplicate = self.dup
      duplicate.each_pair do |k,v|
        tv = duplicate[k]
        duplicate[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? tv.deep_dup : v
      end
      duplicate
    end
  end
end