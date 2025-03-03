module WebmockTurnstileHelperMethods
  def stub_turnstile_success(turnstile_response: {},
      request_body: {"secret"=>BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key, "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"0.0.0.0"})

    turnstile_response.reverse_merge!(
        {"success"=>true, "error-codes"=>[], "challenge_ts"=>Time.now.utc.iso8601(3), "hostname"=>"example.com", "metadata"=>{"result_with_testing_key"=>true}}
    )

    stub_request(:post, BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_validation_url).
         with(
           body: request_body.to_json
         ).to_return(status: 200,
          body: turnstile_response.to_json,
          headers: { 'Content-Type'=>'application/json; charset=utf-8' }
         )

    return turnstile_response
  end

  def stub_turnstile_failure(turnstile_response: {},
    request_body: {"secret"=>BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key, "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"0.0.0.0"})

    turnstile_response.reverse_merge!(
      {"success"=>false, "error-codes"=>["invalid-input-response"], "messages"=>[], "metadata"=>{"result_with_testing_key"=>true}}
    )

    stub_request(:post,  BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_validation_url).
         with(
           body: request_body.to_json
         ).to_return(status: 200,
          body: turnstile_response.to_json,
          headers: { 'Content-Type'=>'application/json; charset=utf-8' }
         )

    return turnstile_response
  end

end
