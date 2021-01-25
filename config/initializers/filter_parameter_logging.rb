# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters.concat [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]

Rails.application.config.filter_parameters += [:password]

Rails.application.config.filter_parameters += [:patron_email]
Rails.application.config.filter_parameters += [:patron_name]
Rails.application.config.filter_parameters += [:patron_institution]
Rails.application.config.filter_parameters += [:intended_use]

