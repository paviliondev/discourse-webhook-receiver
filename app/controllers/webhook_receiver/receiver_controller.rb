class WebhookReceiver::ReceiverController < ApplicationController
  before_action :check_receiver_enabled
  before_action :validate_receiver_settings, only: [:receive]
  before_action :verify_receiver_request, only: [:receive]
  
  skip_before_action :check_xhr,
                     :verify_authenticity_token
      
  def receive
    object_result = find_objects
    puts "OBJECT RESULT: #{object_result.inspect}"
    if object_result[:error] || object_result[:objects].blank?
      message = object_result[:error] || 'failed to find objects'
      return render_error(message)
    end
    
    user_result = find_user
    puts "USER RESULT: #{user_result.inspect}"
    if user_result[:error] || user_result[:user].blank?
      message = user_result[:error] || 'failed to find user'
      return render_error(message)
    end
        
    objects = object_result[:objects]
    user = user_result[:user]
    
    objects.each do |object|
      if object[:type] == 'group'
        group = object[:object]
        message = group.add(user) ?
          "added #{user.username} to #{group.name}" :
          "failed to add #{user.username} to #{group.name}"
        
        WebhookReceiver::Log.create(
          user: user.username,
          group: group.name,
          message: message
        )
      end
    end
    
    render_success("receive request completed")
  end
  
  protected
  
  def check_receiver_enabled
    unless SiteSetting.webhook_receiver_enabled
      render_error('not enabled')
    end
  end
  
  def validate_receiver_settings
    if receiver_opts[:key_object_map].blank? ||
       receiver_opts[:key_path].blank? ||
       receiver_opts[:email_path].blank? ||
       receiver_opts[:secret].blank? ||
       receiver_opts[:secret_header_key].blank? ||
       (
         receiver_opts[:receipt_request] && (
           receiver_opts[:receipt_request_url].blank? ||
           receiver_opts[:receipt_request_path].blank?
         )
       )
  
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
  
  def find_objects
    result = Hash.new
    result[:keys] = recurse(params, receiver_opts[:key_path]).flatten
    result[:error] = "no keys found" if !result[:keys]
    
    return result if result[:error]
    
    if SiteSetting.webhook_receiver_request
      result[:keys].each do |key|
        request_result = post_receipt_request(key)
        
        if !request_result[:error]
          key = request_result[:key]
        end
      end
    end
    
    result[:objects] = []

    result[:keys].each do |key|
      if object_ref = receiver_opts[:key_object_map][key]
        parts = object_ref.split('.')
        type = parts.first
        id = parts.last
        
        if type == 'group'
          if group = Group.find_by_id(id.to_i)
            result[:objects].push(
              type: 'group',
              object: group
            )
          else
            result[:error] = "no group with '#{group_name}' found"
          end
        end
      end
    end
    
    result
  end
  
  def receiver_opts
    @receiver_opts ||= begin
      key_object_map_array = SiteSetting.webhook_receiver_key_object_map.split('|')
      key_object_map = {}
      key_object_map_array.each do |item|
        attrs = item.split(':')
        key = is_int?(attrs.first) ? attrs.first.to_i : attrs.first
        value = is_int?(attrs.second) ? attrs.second.to_i : attrs.second
        key_object_map[key] = value
      end
      
      key_path = build_recursive_path(SiteSetting.webhook_receiver_payload_key_path)
      email_path = build_recursive_path(SiteSetting.webhook_receiver_payload_email_path)
      
      opts = {
        key_object_map: key_object_map,
        key_path: key_path,
        email_path: email_path,
        secret: SiteSetting.webhook_receiver_secret,
        secret_header_key: SiteSetting.webhook_receiver_secret_header_key
      }
      
      if SiteSetting.webhook_receiver_request
        opts[:request_url] = SiteSetting.webhook_receiver_request_url
        opts[:request_path] = build_recursive_path(SiteSetting.webhook_receiver_request_key_path)
      end
      
      opts
    rescue => e
      Hash.new
    end
  end
  
  def build_recursive_path(setting_string)
    setting_string.split('.').map { |p| is_int?(p) ? p.to_i : p }
  end
  
  def is_int?(val)
    /\A[-+]?\d+\z/ === val
  end
  
  def verify_webhook(body, hmac_header, secret)
    calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', secret, body))
    ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
  end
  
  def recurse(data, keys)
    return nil if data.blank?
    k = keys.shift
    
    if k.include?('[]')
      parts = k.split('[]')
      k = parts.first
      arr = data[k]
      
      if arr.is_a?(Array)
        ref_key = nil
        ref_value = nil
        if parts.length > 1
          ref_parts = parts.last.split('=')
          ref_key = ref_parts.first
          ref_value = ref_parts.last
        end
        
        puts "REF KEY: #{ref_key}"
        puts "REF VALUE: #{ref_value}"
        
        result = []
        
        arr.each do |item|
          puts "REF: #{item[ref_key] == ref_value}"
          puts "KEYS: #{keys.inspect}"
          puts "ITEM: #{item.inspect}"
          puts "K: #{k}"
          if ref_key == nil || (item[ref_key] == ref_value)
            if keys.empty?
              result.push(cast_result(item[k]))
            else
              result.push(recurse(item, keys.dup))
            end
          end
        end
        
        result
      end
    else
      result = data[k]
      keys.empty? ? [cast_result(result)] : recurse(result, keys)
    end
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
    ## Success response sent to prevent webhook from repeating
    render plain: "[\"#{message}\"]", status: 200
  end
  
  def render_success(message)
    render plain: "[\"#{message}\"]", status: 200
  end
  
  def post_receipt_request(key)
    url = SiteSetting.webhook_receiver_request_url.sub(':key', key.to_s)
    
    response = Excon.get(url)
    
    begin
      body = JSON.parse(response.body)
    rescue JSON::ParserError => e
      body = {}
    end
    
    if response.status == 200
      result[:key] = recurse(body, receiver_opts[:request_path])
    else
      result[:error] = "Post receipt request error: #{body.values || nil}"
    end
    
    WebhookReceiver::Log.create(
      message: "Post receipt result: #{result[:key] || result[:error]}" 
    )
    
    result
  end
end