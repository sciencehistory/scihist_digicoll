require 'zip'
require 'http'

# We have our solr configuration files at solr/config. We want to upload
# the to a solr instance via solr cloud API's:
#
#     https://lucene.apache.org/solr/guide/7_4/configsets-api.html#configsets-upload
#
# Because prior to Solr 8.7 (released Nov 2020, which we don't have yet), there is no
# way to overright an existing config-set, we need to do a weird dance to update
# the config-set in-place without disturbing the existing Solr collections using it.
# See:
#
#     https://dev.lucene.apache.narkive.com/HI7lTF0o/jira-created-solr-12925-configsets-api-should-allow-update-of-existing-configset
#
# Meanwhile, SearchStax docs and support encourage us to not use the standard Solr API's like
# we are using here, but instead to use proprietary SearchStax API's like:
#     https://www.searchstax.com/docs/staxapi2ZK/#zkcreate
#
# However, those proprietary SearchStax API's are actually a lot more painful to use, and
# of course aren't transferable to non-SearchStax deploys; I can't figure out
# any reason not to use the standard Solr API's.
# SearchStax says their use won't be logged By SearchStax (that seems fine?), and that
# they "aren't secure", but we can access them via the same HTTP Basic Auth credentials
# we are using anyway (SearchStax solr account with "admin" level access), and they are
# available there whether we use them or not, it doens't seem a security issue to use them.
#
# We are going to assume that the config_set name should match the collection name (Solr's conventional
# default).
#
# https://lucene.apache.org/solr/guide/8_6/configsets-api.html
# some parts of https://lucene.apache.org/solr/guide/8_6/collection-management.html#collection-management
class SolrConfigsetUpdater
  attr_reader :collection_name, :conf_dir, :solr_uri, :solr_basic_auth_user, :solr_basic_auth_pass

  # @param collection_name [String] The collection in Solr this instance will be operating upon.
  #
  # @param solr_url [String] Location of Solr Cloud instance. Should be a Solr url ending
  #    in /solr, eg `https://user:pass@example.org:1234/solr`. As you can see, can optionally
  #   include user/pass in URI.
  #
  # @param conf_dir [String] String local path on disk of solr configuration
  #   directory we will be uploading to a Solr Cloud configset. Eg `./solr/conf`.
  def initialize(collection_name:, solr_url:, conf_dir:)
    @collection_name = collection_name
    @conf_dir = conf_dir.to_s
    @solr_uri = URI.parse(solr_url.chomp("/"))

    # take out basic auth user and password into their own variable
    if @solr_uri.user || @solr_uri.password
      @solr_basic_auth_user, @solr_basic_auth_pass = @solr_uri.user, @solr_uri.password
      @solr_uri.user, @solr_uri.password = nil, nil
    end
  end

  # instantiates a SolrConfigsetUpdater using standard values for scihist_digicoll configuration
  def self.configured
    SolrConfigsetUpdater.new(
        solr_url: ScihistDigicoll::Env.solr_base_url,
        collection_name: ScihistDigicoll::Env.solr_collection_name,
        conf_dir: Rails.root + "solr/config"
      )
  end

  # simple upload of a "config set" from @conf_dir to solr/zookeeper via API /admin/configs?action=UPLOAD
  # Will fail if configset_name already exists.
  #
  # @param overwrite send overwrite=true if true, only has meaning in Solr 8.7+
  def upload(configset_name: collection_name, overwrite: false)
    create_temp_zip_file do |tmp_zip_file|
      http_response = http_client.post(
        "#{solr_uri.to_s}/admin/configs?action=UPLOAD&name=#{configset_name}#{'&overwrite=true' if overwrite}",
        body: tmp_zip_file.read
      )

      unless http_response.status.success?
        raise SolrError.new(http_response.body.to_s)
      end

      http_response
    end
  end

  # lists all config sets from `/admin/configs?action=LIST&omitHeader=true`
  #
  # @return [Array<String>]
  def list
    http_response = http_client.get("#{solr_uri.to_s}/admin/configs?action=LIST&omitHeader=true")

    unless http_response.status.success?
      raise SolrError.new(http_response.body.to_s)
    end

    JSON.parse(http_response)["configSets"]
  end

  # deletes a config set with `/admin/configs?action=DELETE&name=myConfigSet`
  def delete(configset_name)
    http_response = http_client.get("#{solr_uri.to_s}/admin/configs?action=DELETE&name=#{configset_name}&omitHeader=true")

    unless http_response.status.success?
      raise SolrError.new(http_response.body.to_s)
    end

    http_response
  end

  # COPIES an existing config set to a new name, using API
  # `/admin/configs?action=CREATE&name=myConfigSet&baseConfigSet=predefinedTemplate`
  def create(from:, to:)
    http_response = http_client.get("#{solr_uri.to_s}/admin/configs?action=CREATE&name=#{to}&baseConfigSet=#{from}")

    unless http_response.status.success?
      raise SolrError.new(http_response.body.to_s)
    end

    http_response
  end

  # reloads the @collection_name with /admin/collections?action=RELOAD&name=newCollection
  # Does not support `async` reloading at present.
  def reload
    http_response = http_client.get("#{solr_uri.to_s}/admin/collections?action=RELOAD&name=#{collection_name}")

    unless http_response.status.success?
      raise SolrError.new(http_response.body.to_s)
    end

    http_response
  end

  # @return [String] current configName set for @collection_name, obtained via
  #   /admin/collections?action=CLUSTERSTATUS aPI
  def config_name
    http_response = http_client.get("#{solr_uri.to_s}/admin/collections?action=CLUSTERSTATUS&collection=#{collection_name}")

    unless http_response.status.success?
      raise SolrError.new(http_response.body.to_s)
    end

    JSON.parse(http_response.body.to_s).dig("cluster", "collections", collection_name, "configName")
  end

  # changes the configName for @collection_name using API
  # /admin/collections?action=MODIFYCOLLECTION&collection=<collection-name>&collection.configName=<newName>
  def change_config_name(new_config_name)
    http_response = http_client.get("#{solr_uri.to_s}/admin/collections?action=MODIFYCOLLECTION&collection=#{collection_name}&collection.configName=#{new_config_name}")

    unless http_response.status.success?
      raise SolrError.new(http_response.body.to_s)
    end

    http_response
  end

  # Uses a strategy where configset is named with timestamp suffix.
  #
  # Uploads confiset, switches to collection to use it, reloads collection, deletes
  # old configset.
  def replace_configset_timestamped
    old_name = config_name
    new_name = configset_timestamp_name

    upload(configset_name: new_name)
    change_config_name(new_name)
    reload
    delete(old_name)
  end

  def configset_timestamp_name
    "#{collection_name}_#{Time.now.utc.iso8601}"
  end

  # Uses a strategy where configset is named with a digest hash of it's contents.
  # After calculating digest, checks to see if already up to date, if so return immediately
  # without doigng anything.
  #
  # Otherwise load configset, switching collection to use it, reload collection, delete
  # prior configset.
  #
  # @return false if no update was needed, else new config_set name.
  def replace_configset_digest
    old_name = config_name
    new_name = configset_digest_name

    if old_name == new_name
      # we're good, it's already there
      return false
    end

    upload(configset_name: new_name)
    change_config_name(new_name)
    reload
    delete(old_name)

    return new_name
  end

  # A name that can be used for a config set based on collection name and a
  # digest fingerprint of config directory contents, used by #replace_configset_digest
  #
  # @return [String]
  def configset_digest_name
    "#{collection_name}_#{conf_dir_digest}"
  end

  # Uses a strategy of updating configset wthat keeps confiset name consistent
  # over time, by doing a multi-step swap of names, working around
  # inability in Solr pre 8.7 to overwrite existing configset name.
  #
  # This involves more steps than #replace_configset_digest or #replace_configset_timestamp.
  # It also may leave things in an unstable state if crashed in the middle.
  # This is mostly here for illustration. It is using the strategy Alex
  # Halovic suggests at: https://dev.lucene.apache.narkive.com/HI7lTF0o/jira-created-solr-12925-configsets-api-should-allow-update-of-existing-configset#post4
  #
  # Copy existing configset to temporary name; switch collection to use temporary name;
  # delete configset at standard name; upload new config under standard name;
  # switch collection back to standard-named configset; delete temporary name.
  #
  #
  def replace_configset_swap
    current_name = self.config_name
    temp_name = "#{current_name}_temp"

    self.create(from: current_name, to: temp_name)
    self.change_config_name(temp_name)
    self.reload
    self.delete(current_name)
    self.upload(configset_name: current_name)
    self.change_config_name(current_name)
    self.reload
    self.delete(temp_name)
  end

  # renames config set used by collection by: copying original configset name to
  # new name; changing collection to use new name; reloading collection; removing
  # configset at original name.
  def rename_config_name(to:)
    from = self.config_name
    self.create(from: from, to: to)
    self.change_config_name(to)
    self.reload
    self.delete(from)
  end

  # Uploads @conf_dir as a configset, and then creates a collection using it,
  # named @collection_name,  via the Solr API
  # /admin/collections?action=CREATE&name=name
  #
  # Useful to bootstrap a brand new collection that wasn't in Solr yet.
  #
  # Will use use @collection_name as name, and the configset specified
  # as @conf_dir.  By default will name the config set same as collection,
  # or pass something else in, possibly using other methods we have.
  #
  # Will error if collection naem or configset_name already exists, you have
  # to deal with that yourself.
  #
  #     updater.create_collection
  #     updater.create_collection(configset_name: updater.configset_digest_name)
  #     updater.create_collection(configset_name: updater.configset_digest_name)
  def upload_and_create_collection(configset_name: collection_name, num_shards: 1)
    self.upload(configset_name: configset_name)

    http_response = http_client.get("#{solr_uri.to_s}/admin/collections?action=CREATE&name=#{collection_name}&collection.configName=#{configset_name}&numShards=#{num_shards}")

    unless http_response.status.success?
      raise SolrError.new(http_response.body.to_s)
    end

    http_response
  end



  class SolrError < StandardError
    attr_reader :status, :response_body_json

    def initialize(solr_response_str)
      json_response = JSON.parse(solr_response_str)
      @status = json_response.dig("responseHeader", "status")
      @response_body_json = json_response
      super(json_response.dig("error", "msg") || solr_response_str)
    rescue JSON::ParserError
      super(solr_response_str)
    end
  end

  protected

  # Returns a digest fingerprint for entire config directory. Uses
  # SHA-256, truncates to first 7 digits by default, or you can specify.
  # (git uses 7 digits by default, although from SHA1, I think
  # should be good enough our purpoes)
  def conf_dir_digest(truncate: 7)
    digest = []
    Dir.glob("#{conf_dir}/**/*").each do |f|
      digest.push(Digest::SHA1.hexdigest(File.open(f).read)) if File.file?(f)
    end
    digest = Digest::SHA1.hexdigest(digest.join(''))
    if truncate
      digest = digest[0..truncate-1]
    end
    digest
  end

  # initializes an http-rb client, with basic_auth if specified
  def http_client
    @http_client ||= begin
      client = HTTP
      if solr_basic_auth_user || solr_basic_auth_pass
        client = client.basic_auth(user: solr_basic_auth_user, pass: solr_basic_auth_pass)
      end
      client
    end
  end

  # Can be called with a block in which case it will yield a Tempfile, and
  # then clean it up after block. Or without a block it just returns the Tempfile
  # and you have to clean it up.
  def create_temp_zip_file
    tmp_zip_file = Tempfile.new([self.class.name, ".zip"]).tap { |t| t.binmode }
    zip = Zip::File.open(tmp_zip_file.path, Zip::File::CREATE) do |zipfile|
      Dir["#{conf_dir}/**/**"].each do |file|
        zipfile.add(file.sub("#{conf_dir}/", ''), file)
      end
    end
    # tell the Tempfile to (re)open so it has a file handle open that can see what ruby-zip wrote
    tmp_zip_file.open

    return tmp_zip_file unless block_given?

    begin
      yield tmp_zip_file
    ensure
      tmp_zip_file.close!
    end
  end
end
