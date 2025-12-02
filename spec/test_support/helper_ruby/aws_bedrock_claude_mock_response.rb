module AwsBedrockClaudeMockResponse
  # AWS sdk returns OpenStruct, we don't want to talk to it, so we mock it here, tests
  # fragile on this being consistent.
  def claude_mock_response(json_return:)
    OpenStruct.new(
      output: OpenStruct.new(
        message: OpenStruct.new(
          role: "assistant",
          content: [
            OpenStruct.new(
              # Claude is insisting on the markdown ``` fencing!
              text: <<~EOS
                ```json
                #{json_return.to_json}
                 ```
              EOS
            )
          ]
        ),
        stop_reason: "end_turn",
        usage: OpenStruct.new(
          input_tokens: 7087, output_tokens: 54, total_tokens: 7141, cache_read_input_tokens: 0, cache_write_input_tokens: 0
        ),
        metrics: OpenStruct.new(latency_ms: 3252)
      )
    )
  end
end
