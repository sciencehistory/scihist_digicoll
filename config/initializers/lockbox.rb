lockbox_master_key = ScihistDigicoll::Env.lookup(:lockbox_master_key)

unless lockbox_master_key.present?
  raise RuntimeError,
    """

    Lockbox master key is missing in production.

    We encrypt our patron information using Lockbox.
    For encryption to work in production, local_env.yml
    must contain a line such as:
        lockbox_master_key: #{Lockbox.generate_key}
    A key can be generated in the Rails console by running:
        \"Lockbox.generate_key\".

    More details can be found at https://github.com/ankane/lockbox .

    """
end

Lockbox.master_key = lockbox_master_key

# If we are rotating, just use ENV
if ENV["LOCKBOX_MASTER_KEY_PREVIOUS"].present?
    Lockbox.default_options[:previous_versions] = [{master_key: ENV["LOCKBOX_MASTER_KEY_PREVIOUS"]}]
end
# To rotate, run eg
#     Lockbox.rotate(SomeModel, attributes: [:email])
#
#
