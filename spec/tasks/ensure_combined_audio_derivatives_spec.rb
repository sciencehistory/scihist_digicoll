require 'rails_helper'
require 'rake'

describe "scihist:oral_history:ensure_combined_audio_derivatives", type: :task, queue_adapter: :test do
  before(:all) do
    Rails.application.load_tasks
  end

  let(:task) { Rake::Task["scihist:oral_history:ensure_combined_audio_derivatives"] }
  after { task.reenable }

  before do
    allow(Rails.logger).to receive(:warn).and_call_original
    # no progress bar in test output
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("INTERACTIVE").and_return("false")
  end

  def unpublish_audio(work)
    work.members.each { |m| m.update_columns(published: false) if m.content_type&.start_with?("audio/") }
  end

  it "enqueues stale, not good, logging reason" do
    good_work = create(:oral_history_work, :combined_derivative)
    stale_work = create(:oral_history_work, :combined_derivative)
    stale_work.oral_history_content.update_columns(combined_audio_fingerprint: "stale")

    expect(Rails.logger).to receive(:warn).with(/#{stale_work.friendlier_id}: bad file \(fingerprint mismatch\)/)
    expect(Rails.logger).to receive(:warn).with(/enqueued 1 jobs/)
    task.invoke

    expect(EnsureCombinedAudioDerivativeJob).to have_been_enqueued.with(stale_work, force: false).exactly(:once)
    expect(EnsureCombinedAudioDerivativeJob).not_to have_been_enqueued.with(good_work, force: false)
  end

  it "enqueues missing file when audio available" do
    work = create(:oral_history_work, :combined_derivative)
    work.oral_history_content.remove_combined_audio!

    expect(Rails.logger).to receive(:warn).with(/#{work.friendlier_id}: missing file/)
    expect(Rails.logger).to receive(:warn).with(/enqueued 1 jobs/)
    task.invoke
    expect(EnsureCombinedAudioDerivativeJob).to have_been_enqueued.with(work, force: false)
  end

  it "skips no file and no available audio" do
    work = create(:oral_history_work, :combined_derivative)
    work.oral_history_content.remove_combined_audio!
    unpublish_audio(work)

    expect(Rails.logger).to receive(:warn).with(/enqueued 0 jobs/)
    task.invoke
    expect(EnsureCombinedAudioDerivativeJob).not_to have_been_enqueued
  end

  it "RECREATE=true forces good ones too" do
    work = create(:oral_history_work, :combined_derivative)
    allow(ENV).to receive(:[]).with("RECREATE").and_return("true")

    expect(Rails.logger).not_to receive(:warn).with(/#{work.friendlier_id}/)
    expect(Rails.logger).to receive(:warn).with(/enqueued 1 jobs/)
    task.invoke
    expect(EnsureCombinedAudioDerivativeJob).to have_been_enqueued.with(work, force: true)
  end
end
