# generally we configure honeybadger in config/honeybadger.yml , but there are
# some things we need to configure in ruby.

Honeybadger.configure do |config|

  # Keep secrets ouf of honeybadger notifications.
  # Suggested by https://github.com/tulibraries/tul_cob/commit/27809fbebbc34b956a980976020d0de9db921f6c

  solr_url = ScihistDigicoll::Env.lookup(:solr_url)
  if solr_url
    parsed = URI.parse(solr_url)
    solr_user = parsed.user
    solr_password = parsed.password
  end

  secrets = {
    solr_uri_user: solr_user,
    solr_uri_password: solr_password,
    smtp_username: ScihistDigicoll::Env.lookup(:smtp_username),
    smtp_password: ScihistDigicoll::Env.lookup(:smtp_password),
    aws_secret_access_key: ScihistDigicoll::Env.lookup(:aws_secret_access_key)

  }.delete_if { |_k, v| v.blank? }

  config.before_notify do |notice|
    # SHI customization, let honey badger fingerprint be supplied in context, so
    # we can force grouping of errors that would not otherwise be grouped from
    # an eg
    #
    #    ActiveSupport.error_reporter&.report(..., context: { honeybadger_fingerprint: f } _
    if notice.context && notice.context[:honeybadger_fingerprint]
      notice.fingerprint = notice.context[:honeybadger_fingerprint]
      notice.context.delete(:honeybadger_fingerprint)
    end

    # And similarly, let us pass through custom HB error message
    if notice.context && notice.context[:honeybadger_error_message]
      notice.error_message = notice.context[:honeybadger_error_message]
      notice.context.delete(:honeybadger_error_message)
    end

    # Filter secrets from error messages, AFTER any customization we've done of them.
    secrets.each do |secret_name, secret_value|
      next if secret_value.blank?
      notice.error_message = notice.error_message.gsub(secret_value, "[:#{secret_name}]")
    end
  end
end
