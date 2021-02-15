module ::WebhookReceiver
  class Engine < ::Rails::Engine
    engine_name 'webhook_receiver'
    isolate_namespace WebhookReceiver
  end
  
  PLUGIN_NAME ||= "webhook-receiver"
end