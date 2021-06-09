class TestingSleepJob < ApplicationJob
  def perform(sleep_seconds=10)
    sleep sleep_seconds
  end
end
