lockbox_master_key = ScihistDigicoll::Env.lookup(:lockbox_master_key)

unless lockbox_master_key.present?
  raise RuntimeError,
    """

    Lockbox master key is missing!

    This application encrypts patron information using Lockbox.
    For it to work, you need to make sure that local_env.yml
    contains a line such as:
        lockbox_master_key: #{Lockbox.generate_key}
    A key can be generated in the Rails console by running:
        \"Lockbox.generate_key\".

    More details can be found at https://github.com/ankane/lockbox .

    """
end

Lockbox.master_key = lockbox_master_key