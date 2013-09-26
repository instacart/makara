# Makara

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'makara'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install makara

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Todo

Allow a cookie cache store to be provided by the middleware. If the cache store is set to :cookie then instantiate a cookie store based on the current request. After the response is handled ensure the store is reset to :cookie.
