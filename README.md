PlugRailsCookieSessionStore
===========================

Rails compatible Plug session store.

This allows you to share session information between Rails and a Plug-based framework like Phoenix.

It reads and writes the session cookies of Rails 4 and Rails 5 applications (and Rails 3.2, see below).

## Installation

Add PlugRailsCookieSessionStore as a dependency to your `mix.exs` file:

```elixir
def deps do
  [{:plug_rails_cookie_session_store, "~> 0.1"}]
end
```

And do not forget to add `:plug_rails_cookie_session_store` to the applications list.

## How to use with Phoenix

#### Copy/share the encryption information from Rails to Phoenix.

There are 4 things to copy:
* secret_key_base
* signing_salt
* encryption_salt
* session_key
 
The `secret_key_base` can be found usually in the Rails' `secrets.yml` file and should be copied to Phoenix's `config.exs` file. There should already be a key named like that and you should override it.

The other three values can be found somewhere in the initializers directory of your Rails project:

```ruby
Rails.application.config.session_store :cookie_store, key: '_SOMETHING_HERE_session'
Rails.application.config.action_dispatch.encrypted_cookie_salt =  'encryption salt'
Rails.application.config.action_dispatch.encrypted_signed_cookie_salt = 'signing salt'
```

Most applications don't set the salts. In that case Rails 4 and Rails 5 use `"encrypted cookie"` as the `encryption_salt` and `"signed encrypted cookie"` as the `signing_salt`.

#### Configure the Cookie Store in Phoenix. 

Edit the `endpoint.ex` file and add the following:

```elixir
# ...
plug Plug.Session,
  store: PlugRailsCookieSessionStore,
  key: "_SOMETHING_HERE_session",
  domain: '.myapp.com',
  secure: true,
  signing_with_salt: true,
  signing_salt: "signing salt",
  encrypt: true,
  encryption_salt: "encryption salt",
  key_iterations: 1000,
  key_length: 64,
  key_digest: :sha,
  serializer: Poison # see serializer details below
end
```

`key_iterations: 1000`, `key_length: 64` and `key_digest: :sha` match how Rails 4 and Rails 5 derive the cookie keys from `secret_key_base`, so keep them as they are.

Rails 5.2 applications created with `config.load_defaults 5.2` encrypt cookies with AES-256-GCM, which this store does not support. Keep such an application on the cookie format of Rails 4 and Rails 5.0/5.1 with:

```ruby
Rails.application.config.action_dispatch.use_authenticated_cookie_encryption = false
```

#### Set up a serializer

Plug & Rails must use the same strategy for serializing cookie data.

- __JSON__: Since 4.1, Rails defaults to serializing cookie data with JSON. Support this strategy by getting a JSON serializer and passing it to `Plug.Session`. For example, add `Poison` to your dependencies, then:

  ```elixir
  plug Plug.Session,
    store: PlugRailsCookieSessionStore,
    # ... see encryption config above
    serializer: Poison
  end
  ```  

  You can confirm that your app uses JSON by searching for

  ```ruby
  Rails.application.config.action_dispatch.cookies_serializer = :json
  ```

  in an initializer.

- __Marshal__: Previous to 4.1, Rails defaulted to Ruby's [`Marshal` library](http://ruby-doc.org/core-2.3.0/Marshal.html) for serializing cookie data. You can deserialize this by adding [`ExMarshal`](https://hex.pm/packages/ex_marshal) to your project and defining a serializer module:

  ```elixir
  defmodule RailsMarshalSessionSerializer do
    @moduledoc """
    Share a session with a Rails app using Ruby's Marshal format.
    """
    def encode(value) do
      {:ok, ExMarshal.encode(value)}
    end

    def decode(value) do
      {:ok, ExMarshal.decode(value)}
    end
  end
  ```

  Then, pass that module as a serializer to `Plug.Session`:

  ```elixir
  plug Plug.Session,
    store: PlugRailsCookieSessionStore,
    # ... see encryption config above
    serializer: RailsMarshalSessionSerializer
  end
  ```
  
- __Rails 3.2__: Rails 3.2 uses unsalted signing, to make Phoenix share session with Rails 3.2 project you need to set up `ExMarshal` mentioned above, with following configuration in your `Plug.Session`:

  ```elixir
  plug Plug.Session,
    store: PlugRailsCookieSessionStore,
    # ... see encryption/ExMarshal config above
    signing_with_salt: false,
  end
  ```
  

#### That's it!

To test it, set a session value in your Rails application:

```elixir
session[:foo] = 'bar'
```
    
And print it on Phoenix in whatever Controller you want:

```elixir
Logger.debug get_session(conn, "foo")
```
