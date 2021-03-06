# GitSimple

[![Gem Version](https://badge.fury.io/rb/git_simple.svg)](http://badge.fury.io/rb/git_simple)
[![Code Climate](https://codeclimate.com/github/acant/git_simple.svg)](https://codeclimate.com/github/acant/git_simple)
[![Build Status](https://travis-ci.org/acant/git_simple.svg?branch=master)](https://travis-ci.org/acant/git_simple)
[![Inline docs](http://inch-ci.org/github/acant/git_simple.svg?branch=master)](http://inch-ci.org/github/acant/git_simple)
[![Dependency Status](https://gemnasium.com/acant/git_simple.svg)](https://gemnasium.com/acant/git_simple)
[![Test Coverage](https://codeclimate.com/github/acant/git_simple/badges/coverage.svg)](https://codeclimate.com/github/acant/git_simple/coverage)

Git [porcelain layer](https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain)
in Ruby, for bare and working repositories. The [rugged gem](https://github.com/libgit2/rugged),
and [libgit2](https://libgit2.github.com/), are used to provide the git plumbing.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'git_simple'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install git_simple

## Usage

Clone from a remote repository:

```
GitSimple.clone('git@server:user/repo_name.git')
```

Or a new commit to the repository:

```
GitSimple('repo')
  .add('new_file')
  .rm('old_file')
  .commit('Made some changes', name: 'Art T. Fish', email: 'afish@example.com')
```

## Alternative Projects

Alternative gem which provide a Ruby porcelain type git interface exist, and
will be listed here:

* https://rubygems.org/gems/grit
* https://rubygems.org/gems/git
* https://rubygems.org/gems/rugged-easy
* https://rubygems.org/gems/minigit
* https://rubygems.org/gems/asgit
* https://github.com/schacon/simplegit

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/acant/git_simple. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the GitSimple project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/acant/git_simple/blob/master/CODE_OF_CONDUCT.md).
