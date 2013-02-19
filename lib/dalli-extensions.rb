require 'active_support/cache/dalli_store'
require 'active_support/core_ext/module/aliasing'

ActiveSupport::Cache::DalliStore.class_eval do

  MEMCACHED_KEYS = "memcached_keys"

  alias_method :old_write_entry, :write_entry
  def write_entry(key, entry, options)
    keys = get_memcached_keys
    unless keys.include?(key)
      keys << key
      return false unless old_write_entry(MEMCACHED_KEYS, keys.to_yaml, {})
    end
    old_write_entry(key, entry, options)
  end

  alias_method :old_delete_entry, :delete_entry
  def delete_entry(key, options)
    return_entry_dalli = old_delete_entry(key, options)
    return false unless return_entry_dalli
    keys = get_memcached_keys
    if keys.include?(key)
      keys -= [ key ]
      old_write_entry(MEMCACHED_KEYS, keys.to_yaml, {})
    end
    return_entry_dalli
  end

  def delete_matched(matcher, options = nil)
    return_entry_dalli = true
    deleted_keys = []
    keys = get_memcached_keys
    keys.each do |key|
      if return_entry_dalli && key.match(matcher)
        deleted_keys << key if (return_entry_dalli = old_delete_entry(key, options))
      end
    end
    len = keys.length
    keys -= deleted_keys
    old_write_entry(MEMCACHED_KEYS, keys.to_yaml, {}) if keys.length < len
    return_entry_dalli
  end

private
  def get_memcached_keys
    begin
      YAML.load read(MEMCACHED_KEYS)
    rescue TypeError
      []
    end
  end

end
