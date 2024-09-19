 require "rails/console/methods"
 require "rails/commands/console/irb_console"


# Over-ride rails method that puts the env in console prompt,
# so console prompt in staging says 'staging'.
#
# even though our staging uses "production" env, we want it to
# show up differently in console, so prompt can serve it's cautionary function to
# distinguish production


module OverrideIrbConsoleColorizedEnv
  def colorized_env
    if ScihistDigicoll::Env.staging?
      IRB::Color.colorize("staging", [:YELLOW])
    else
      super
    end
  end
end

Rails::Console::IRBConsole.prepend OverrideIrbConsoleColorizedEnv

