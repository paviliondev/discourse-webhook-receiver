class WebhookReceiver::Log
  include ActiveModel::Serialization
  
  attr_accessor :user, :group, :message, :date
  
  PAGE_LIMIT = 100
  
  def initialize(attrs)
    attrs = attrs.with_indifferent_access
    @user = attrs['user']
    @group = attrs['group']
    @message = attrs['message']
    @date = attrs['date']
  end
  
  def self.create(opts)
    log_id = SecureRandom.hex(8)
    
    PluginStore.set(WebhookReceiver::PLUGIN_NAME,
      "log_#{log_id}",
      opts.merge(date: Time.now)
    )
  end
  
  def self.list_query
    PluginStoreRow.where("
      plugin_name = '#{WebhookReceiver::PLUGIN_NAME}' AND
      key LIKE 'log_%' AND
      (value::json->'date') IS NOT NULL
    ").order("value::json->>'date' DESC")
  end
  
  def self.add_filter_query(attr, value)
    "AND "
  end
  
  def self.list(page: 0, filter: '')
    list = list_query
    
    if filter
      list = list.where("
        value::json->>'user' ~ '#{filter}' OR
        value::json->>'group' ~ '#{filter}'
      ")
    end
    
    list.limit(PAGE_LIMIT)
      .offset(page * PAGE_LIMIT)
      .map { |r| self.new(JSON.parse(r.value)) }
  end
end