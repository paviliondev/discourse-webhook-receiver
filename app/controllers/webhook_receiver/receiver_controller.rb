class WebhookReceiver::ReceiverController < ApplicationController
  before_action :check_receiver_enabled
  before_action :validate_receiver_settings, only: [:receive]
  before_action :verify_receiver_request, only: [:receive]
  
  skip_before_action :check_xhr,
                     :verify_authenticity_token
      
  def receive
    group_result = find_group
        
    if group_result[:error] || group_result[:group].blank?
      message = group_result[:error] || 'failed to find group'
      return render_error(message)
    end
    
    user_result = find_user
    
    if user_result[:error] || user_result[:user].blank?
      message = user_result[:error] || 'failed to find user'
      return render_error(message)
    end
    
    group = group_result[:group]
    user = user_result[:user]

    if group.add(user)
      message = "added #{user.username} to #{group.name}"
      
      WebhookReceiver::Log.create(
        user: user.username,
        group: group.name,
        message: message 
      )
      
      render_success(message)
    else
      render_error("failed to add #{user.username} to #{group.name} ")
    end
  end
  
  protected
  
  def check_receiver_enabled
    unless SiteSetting.webhook_receiver_enabled
      render_error('not enabled')
    end
  end
  
  def validate_receiver_settings
    if receiver_opts[:key_group_map].blank? ||
       receiver_opts[:key_path].blank? ||
       receiver_opts[:email_path].blank? ||
       receiver_opts[:secret].blank? ||
       receiver_opts[:secret_header_key].blank?
  
       render_error('incomplete settings')
    end
  end
  
  def verify_receiver_request
    request.body.rewind
    body = request.body.read
    
    unless verify_webhook(
      body,
      request.headers[receiver_opts[:secret_header_key]],
      receiver_opts[:secret]
    )   
      render_error('webhook not verified')
    end
  end
  
  def find_user
    email = recurse(params, receiver_opts[:email_path])
    result = Hash.new
    
    unless email
      error = "no email found at email_path"
      
      WebhookReceiver::Log.create(message: error)
      result[:error] = error
      return result
    end
    
    if user = User.find_by_email(email)
      result[:user] = user
    else
      error = "no user with email '#{email}' found"
      WebhookReceiver::Log.create(message: error)
      result[:error] = error
    end
    
    result
  end
  
  def find_group
    result = Hash.new
    result[:key] = recurse(params, receiver_opts[:key_path])
    
    result[:error] = "no key found" if !result[:key]
    return result if result[:error]
    
    if SiteSetting.webhook_receiver_post_receipt_request
      result = post_receipt_request(result) 
    end
    
    return result if result[:error]
    
    receiver_opts[:key_group_map].each do |k, group_name|
      if k == result[:key]
        if group = Group.find_by(name: group_name)
          result[:group] = group
        else
          result[:error] = "no group with '#{group_name}' found"
        end
      end
    end
    
    result
  end
  
  def receiver_opts
    @receiver_opts ||= begin
      key_group_map_array = SiteSetting.webhook_receiver_key_group_map.split('|')
      key_group_map = {}
      key_group_map_array.each do |item|
        attrs = item.split(':')
        key_group_map[attrs.first] = attrs.second
      end
      
      key_path = build_recursive_path(SiteSetting.webhook_receiver_payload_key_path)
      email_path = build_recursive_path(SiteSetting.webhook_receiver_payload_email_path)
      
      {
        key_group_map: key_group_map,
        key_path: key_path,
        email_path: email_path,
        secret: SiteSetting.webhook_receiver_secret,
        secret_header_key: SiteSetting.webhook_receiver_secret_header_key
      }
    rescue => e
      Hash.new
    end
  end
  
  def build_recursive_path(setting_string)
    setting_string.split('.').map { |p| p.scan(/\D/).empty? ? p.to_i : p }
  end
  
  def verify_webhook(body, hmac_header, secret)
    calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', secret, body))
    ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
  end
  
  def recurse(data, keys)
    return nil if data.blank?
    k = keys.shift
    result = data[k]
    keys.empty? ? cast_result(result) : recurse(result, keys)
  end
  
  def cast_result(result)
    if result.is_a?(String)
      begin
        JSON.parse(result)
      rescue JSON::ParserError
        result
      end
    else
      result
    end
  end
  
  def render_error(message)
    WebhookReceiver::Log.create(message: message)
    
    render plain: "[\"#{message}\"]", status: 200 
    ## Success response sent to prevent webhook from repeating
  end
  
  def render_success(message)
    render plain: "[\"#{message}\"]", status: 200
  end
  
  def post_receipt_request(result)
    url = SiteSetting.webhook_receiver_post_receipt_request_url.sub(':key', result[:key].to_s)
    
    response = Excon.get(url)
    
    begin
      body = JSON.parse(response.body)
    rescue JSON::ParserError => e
      body = {}
    end
    
    if response.status == 200
      ## TO FIX: Shopify specific 
      metafield = (body['metafields'] || []).select { |f| f['key'] == 'group' }.first
      
      if metafield.present?
        result[:key] = metafield['value']
      else
        result[:error] = "No group key in: #{body['metafields']}" 
      end
    else
      result[:error] = "Post receipt request error: #{body.values || nil}"
    end
    
    WebhookReceiver::Log.create(
      message: "Post receipt result: #{result[:key] || result[:error]}" 
    )
    
    result
  end
end