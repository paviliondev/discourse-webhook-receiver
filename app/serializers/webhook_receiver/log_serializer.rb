class WebhookReceiver::LogSerializer < ApplicationSerializer
  attributes :user, :group, :message, :date
end