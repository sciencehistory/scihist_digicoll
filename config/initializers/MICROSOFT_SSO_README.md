# Microsoft SSO
By default, when you install the app, users log in using a combination of a username and password.

If you want, though, you can try using Microsoft’s Entra to authenticate users instead.
 - [This PR](https://github.com/sciencehistory/scihist_digicoll/pull/2769) has a lot of details and context.
 - Authentication is provided by two gems, `omniauth-entra-id` and `omniauth-rails_csrf_protection`.
 - A feature switch, ENV setting `:log_in_using_microsoft_sso`, determines whether the app uses Microsoft SSO to sign in or not. This is turned off by default, so if you want to use it in Dev, you will need to add some env variables (see “using SSO in dev”).
 - The Microsoft auth provider is configured with three more ENV settings:
	- :microsoft_sso_client_id identifies the app to Microsoft SSO;
	- :microsoft_sso_client_secret authenticates the app to Microsoft SSO;
	- :microsoft_sso_tenant_id identifies the Microsoft SSO directory the app wants to check (namely the Institute one. This ID is the same for dev, staging and prod.)
 - Most of the configuration is done in two files:
	 - config/initializers/devise.rb
	 - config/routes.rb

## Using SSO in a development environment
Single sign-on is turned off by default in development. If you want to try using SSO in development, you can temporarily add something like the following to your local_env.yml file:
 - log_in_using_microsoft_sso:  true
 - microsoft_sso_client_id:     [...]
 - microsoft_sso_client_secret: [...]
 - microsoft_sso_tenant_id:     [...]