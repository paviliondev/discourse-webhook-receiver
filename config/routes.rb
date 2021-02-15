OAuth2Extension::Engine.routes.draw do
  post 'receive' => 'receiver#receive'
end

Discourse::Application.routes.append do
  mount WebhookReceiver::Engine, at: 'webhook-receiver'
  get '/admin/plugins/webhook-receiver' => 'webhook_receiver/admin#index', constraints: AdminConstraint.new
end