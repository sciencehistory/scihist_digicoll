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
    secrets.each do |secret_name, secret_value|
      notice.error_message.gsub!(secret_value, "[:#{secret_name}]") unless secret_value.blank?
    end

    # Make sure all get combined into ONE error group from HB, slight differences in how
    # they were reported made them many errors, too noisy.

  end
end
