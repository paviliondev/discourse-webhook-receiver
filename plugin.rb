# name: discourse-webhook-receiver
# about: Receive webhook payloads in Discourse
# version: 0.0.1
# authors: Angus McLeod
# url: https://github.com/paviliondev/discourse-webhook-receiver

plugin_enabled_setting :webhook_receiver_enabled
add_admin_route 'webhook_receiver.title', 'webhook-receiver'
register_asset 'stylesheets/common/webhook_receiver.scss'

after_initialize do
  %w{
    ../lib/webhook_receiver/engine.rb
    ../lib/webhook_receiver/log.rb
    ../app/controllers/webhook_receiver/admin_controller.rb
    ../app/controllers/webhook_receiver/receiver_controller.rb
    ../app/serializers/webhook_receiver/log_serializer.rb
    ../config/routes.rb
  }.each do |path|
    load File.expand_path(path, __FILE__)
  end
end