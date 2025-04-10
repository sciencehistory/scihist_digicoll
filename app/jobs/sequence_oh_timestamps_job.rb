class SequenceOhTimestampsJob < ApplicationJob
  def perform(work)
    # looks like Shrine IO is not IO-like-enough for Docx gem, we have to
    # download
    work.oral_history_content.input_docx_transcript.download do |local_file|
      output = SequenceOhTimestamps.new(
        local_file,
        work&.oral_history_content&.combined_audio_component_metadata&.dig("start_times")&.to_h
      ).process

      # let's make a proper filename from input filename with `-sequenced` added.
      filename = work.oral_history_content.input_docx_transcript.metadata["filename"].gsub(/(\.\w+)$/) { "-seqeuenced#{$1}" }

      # shrine  way to assign explicit mime-type and file-name, why not
      work.oral_history_content.output_sequenced_docx_transcript_attacher.
        model_assign(output, metadata: { mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", filename: filename })

      work.oral_history_content.save!

      output.unlink
    end
  end

end
