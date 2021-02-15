class WebhookReceiver::AdminController < Admin::AdminController
  def index
    render_serialized(
      WebhookReceiver::Log.list(page: params[:page].to_i, filter: params[:filter]),
      WebhookReceiver::LogSerializer
    )
  end
end