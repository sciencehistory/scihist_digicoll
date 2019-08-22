
  # TODO: Make sure we don't include non-published things!
  class OaiPmhController < ApplicationController
    class WorkOaiProvider < OAI::Provider::Base
      repository_name 'Science History Institute Digital Collections'
      repository_url "#{ScihistDigicoll::Env.lookup!(:app_url_base)}/oai"

      record_prefix 'oai:sciencehistoryorg'
      admin_email ScihistDigicoll::Env.lookup!(:admin_email)

      # Try to get one from the db, if we can't this is one we have in production
      sample_id (Work.first.friendlier_id rescue "tq57nr00k")

      # Note we limit to published true, and pre-load leaf_representative for performance
      source_model OAI::Provider::ActiveRecordWrapper.new(Work.where(published: true).includes(:leaf_representative))
    end


    # Based on docs in ruby oai gem.
    # https://github.com/code4lib/ruby-oai/blob/1886646f34576fcda3f7a36c9223cad058daedfc/lib/oai/provider.rb#L117-L125
    def index
      provider = WorkOaiProvider.new
      response =  provider.process_request(oai_params.to_h)
      render :body => response, :content_type => 'text/xml'
    end

    private

    def oai_params
      params.permit(:verb, :identifier, :metadataPrefix, :set, :from, :until, :resumptionToken)
    end
  end
