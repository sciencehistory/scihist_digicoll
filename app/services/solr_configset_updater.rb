require 'zip'
require 'http'

# A utility class for working with Solr Cloud APIs to manage "config sets"
# (Solr config directories uploaded to solr cloud), assign them to collections,
# and update the config set assigned to a collection. We have a solr config
# directory on local disk, and want to upload and update it as a config set
# in the Solr Cloud instance.
#
# To do this we implement wrappers for the entire Solr
# [ConfigSet API](https://lucene.apache.org/solr/guide/8_6/configsets-api.html) and
# just a couple relevant actions in the [Collections API](https://lucene.apache.org/solr/guide/8_6/collections-api.html)
# Both kind of jammed into this one class -- but keep it simple, this code isn't
# super elegantly designed, it's just enough to give us the tools we need for our use cases.
#
# This code is written to be perhaps extractable from this application, to general-purpose
# shared code.
#
# An updater object is for a specific collection, in a specific Solr Cloud instance,
# and using a specific local filesystem path as config directory source:
#
#     updater = SolrConfigsetUpdater.new(
#       solr_url: ENV['solr_url'],
#       collection_name: "myCollection",
#       conf_dir: Rails.root + "solr/conf"
#      )
#      # Or for scihist-digicoll app specifically, get those values
#      # from the standard configured places:
#      updater = SolrConfigsetUpdater.configured
#
# # API wrappers
#
# A bunch of methods straightforwardly wrap Solr API, which  can be useful in a console to
# explore what's going on with config sets and collection settings, or can be used to
# build whatever logic you want.
#
# ## Configset API
#
#     updater.list # list config sets
#     updater.upload(config_set_name: "some_name") # upload from local dir to named config set
#     updater.delete(config_set_name) # delete named config set name
#     updater.create(from: source, to: dest) # the "create" Solr API call makes a config set copy
#
# ## Collection API
#
#     updater.config_name # configset name set currently set for collection
#     updater.change_config_name(new_name) # change config set collection uses
#     updater.reload # send reload to configured collection
#     updater.create_collection(configset_name: name) # create a Solr collection using named config set
#     updater.list_collections # list all collections in Solr instance
#
# # Higher-level logic composing those
#
# In Solr 8.7+, you are allowed to overwrite an existing configset, so updating config set for
# an existing collection without downtime is straightforward:
#
#     updater.upload(config_set_name: name_used, overwrite_true)
#     updater.reload
#
# The end. But we don't have Solr 8.7 yet, so various more complicated dances
# are needed to get a collection config set updated. See #replace_configset_timestamped,
# #replace_configest_digest, and #replace_configset_swap.
#
# Really #replace_configset_digest is a good algorithm, which you might want to use even
# if you have Solr 8.7, because it can avoid doing an upload/rename unless config
# content has actually changed, so is nice to use on every deploy similar to Rails migrations.
#
# Also, the shortcut #upload_and_create_collection is available to bootstrap
# from having no collection created, to having a collection created based on your
# local conf_dir directory.
#
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

      parse_and_verify_response(http_response)
    end
  end

  # lists all config sets from `/admin/configs?action=LIST&omitHeader=true`
  #
  # @return [Array<String>]
  def list
    http_response = http_client.get("#{solr_uri.to_s}/admin/configs?action=LIST&omitHeader=true")

    parsed = parse_and_verify_response(http_response)

    parsed["configSets"]
  end

  # deletes a config set with `/admin/configs?action=DELETE&name=myConfigSet`
  def delete(configset_name)
    http_response = http_client.get("#{solr_uri.to_s}/admin/configs?action=DELETE&name=#{configset_name}&omitHeader=true")

    parse_and_verify_response(http_response)
  end

  # COPIES an existing config set to a new name, using API
  # `/admin/configs?action=CREATE&name=myConfigSet&baseConfigSet=predefinedTemplate`
  def create(from:, to:)
    http_response = http_client.get("#{solr_uri.to_s}/admin/configs?action=CREATE&name=#{to}&baseConfigSet=#{from}")

    parse_and_verify_response(http_response)
  end

  # reloads the @collection_name with /admin/collections?action=RELOAD&name=newCollection
  # Does not support `async` reloading at present.
  def reload
    http_response = http_client.get("#{solr_uri.to_s}/admin/collections?action=RELOAD&name=#{collection_name}")

    parse_and_verify_response(http_response)
  end

  # @return [String] current configName set for @collection_name, obtained via
  #   /admin/collections?action=CLUSTERSTATUS aPI
  def config_name
    http_response = http_client.get("#{solr_uri.to_s}/admin/collections?action=CLUSTERSTATUS&collection=#{collection_name}")

    parsed = parse_and_verify_response(http_response)

    parsed.dig("cluster", "collections", collection_name, "configName")
  end

  # changes the configName for @collection_name using API
  # /admin/collections?action=MODIFYCOLLECTION&collection=<collection-name>&collection.configName=<newName>
  #
  # Warning sometimes errors leave things in an inconsistent state unless we change back,
  # we try to recover from that.
  #
  # Note that if the configset had malformed or illegal XML configuration, the error seems to look
  # something like:
  #   org.apache.solr.client.solrj.impl.HttpSolrClient$RemoteSolrException:Error from server at $URL: Unable to reload core [$CORE_NAME]
  def change_config_name(new_config_name)
    original_name = self.config_name
    http_response = http_client.get("#{solr_uri.to_s}/admin/collections?action=MODIFYCOLLECTION&collection=#{collection_name}&collection.configName=#{new_config_name}")

    parse_and_verify_response(http_response)
  rescue SolrError => e
    # We may have left things in an inconsistent state, try to change back, without
    # catching error or anything.
    begin
      http_client.get("#{solr_uri.to_s}/admin/collections?action=MODIFYCOLLECTION&collection=#{collection_name}&collection.configName=#{original_name}")
    rescue StandardError
    end

    raise e
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
      # we're good, we are already using this configuration
      return false
    end

    begin
      upload(configset_name: new_name)
    rescue SolrConfigsetUpdater::SolrError => e
      # Normally it shouldn't already exist, but can on a revert to a past exact identical
      # configset. if it happens, it just means we don't need to create it, it already exists,
      # and can continue.
      if e.message =~ /The configuration #{new_name} already exists/
        # no-op, continue
      else
        raise e
      end
    end

    # set to use new name
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
    self.create_collection(configset_name: configset_name, num_shards: num_shards)
  end

  # Creates a collection under @collection_name via Solr Cloud API
  # `/admin/collections?action=CREATE&name=name`, based on configset_name
  # specified -- by default the collection_name itself.
  def create_collection(configset_name: collection_name, num_shards: 1)
    http_response = http_client.get("#{solr_uri.to_s}/admin/collections?action=CREATE&name=#{collection_name}&collection.configName=#{configset_name}&numShards=#{num_shards}")

    parse_and_verify_response(http_response)
  end

  # List collections using Solr Cloud API `/admin/collections?action=LIST`
  #
  # @return [Array<String>]
  def list_collections
    http_response = http_client.get("#{solr_uri.to_s}/admin/collections?action=LIST")

    parsed = parse_and_verify_response(http_response)

    parsed["collections"]
  end

  class SolrError < StandardError
    attr_reader :status, :response_body_json

    def initialize(str, status:nil, response_body_json: nil)
      @status = status
      @response_body_json = response_body_json
      super(str)
    end
  end

  protected

  # returns JSON-parsed hash for succesful response.
  #
  # raises a SolrError if it looks like a bad response
  #
  # Bad responses sometimes but not always have a non-200 HTTP result code.
  # A bad response may be a message in "failure", or in "error.msg", or maybe
  # in neither. :(
  #
  # @param response [HTTP::Response] A solr API response with JSON body
  def parse_and_verify_response(response)
    parsed = JSON.parse(response.body.to_s)

    if !response.status.success? || parsed["failure"]
      raise SolrError.new(
        parsed["failure"] || parsed.dig("error", "msg") || response.body.to_s,
        status: response.status,
        response_body_json: parsed
      )
    end

    return parsed
  rescue JSON::ParserError => e
    raise SolrError.new("Could not parse: #{e.message}: #{response.body.to_s}")
  end

  # Returns a digest fingerprint for entire config directory. Uses
  # SHA-256, truncates to first 7 digits by default, or you can specify.
  # (git uses 7 digits by default, although from SHA1, I think
  # should be good enough our purpoes)
  def conf_dir_digest(truncate: 7)
    digest = []
    Dir.glob("#{conf_dir}/**/*").sort.each do |f|
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
