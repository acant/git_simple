require 'etc'

class GitSimple
  # Miscellaneous methods to support GitSimple.
  module Utils
    # @overload to_pathname(pathname)
    #   @param [String, Pathname] pathname
    #
    # @overload to_pathname(*args)
    #   @param [Array<String>] *args
    #
    # @return [Pathname]
    def self.to_pathname(*args)
      flattened_args = args.flatten.compact

      return Pathname(flattened_args.first) if flattened_args.length == 1
      Pathname(File.join(flattened_args))
    end

    # @param [Array<String, Array<String>, Pathname>] patterns
    # @param [String, Array<String>, Pathname] base
    # @yieldparam [Pathname] relative_path to the base directory path
    # @yieldparam [Pathname] realpath
    #
    # @return [void]
    def self.each_with_glob(patterns, base, &block)
      base_pathname = to_pathname(base)

      pathnames =
        [patterns]
        .flatten
        .compact
        .map { |x| base_pathname + Utils.to_pathname(x) }
        .map { |x| x.directory? ? Pathname.glob(x.join('**/*')) : Pathname.glob(x) }
        .flatten
        .reject(&:directory?)

      pathnames.each do |pathname|
        block.call(
          pathname.relative_path_from(base_pathname),
          pathname.realpath
        )
      end
    end

    # Use the GitCloneURL to parse the URL, whether it is specified as a string
    # or as a git remote with a URL.
    #
    # @param [Rugged::Remote, String] remote_or_url
    #
    # @return [GitCloneUrl]
    def self.git_clone_url(remote_or_url)
      remote_url =
        if remote_or_url.respond_to?(:url)
          remote_or_url.url
        else
          remote_or_url
        end
      GitCloneUrl.parse(remote_url)
    end

    # @param [Rugged::Remote, String] remote_or_url
    # @param [Hash] options
    # @option options [String] :username
    # @option options [String] :password
    # @option options [String] :ssh_passphrase
    #
    # @return [Hash]
    def self.build_remote_options(remote_or_url, options = {})
      uri = git_clone_url(remote_or_url)

      case uri.scheme
      when 'http', 'https'
        if options[:user] && options[:password]
          {
            credentials: Rugged::Credentials::UserPassword.new(
              username: options[:user],
              password: options[:password]
            )
          }
        else
          {}
        end
      else
        if uri.is_a?(URI::SshGit::Generic) || uri.scheme == 'ssh'
          # TODO: How to figure out check if the SSH agent is available and use
          # it in that case.
          # {
          #   credentials: Rugged::Credentials::SshKeyFromAgent.new(
          #     username: uri.user || options[:user]
          #   )
          # }
          {
            credentials: Rugged::Credentials::SshKey.new(
              username:   uri.user || options[:user] || Etc.getlogin,
              publickey:  Pathname(ENV['HOME']).join('.ssh/id_rsa.pub').to_s,
              privatekey: Pathname(ENV['HOME']).join('.ssh/id_rsa').to_s,
              passphrase: options[:ssh_passphrase]
            )
          }
        else
          # Anonymous protocols (i.e., file, git)
          {}
        end
      end
    end

    # Separate out an options has from the end of the arguments.
    #
    # @param [Array] *args the method will try to split the options out of
    #
    # @return [Array(Array, Hash)]
    def self.split_options(*args)
      return [args.first(args.length - 1), args.last] if args.last.is_a?(Hash)

      [args, {}]
    end

    # @overload clone(pathname_or_remote_url, options)
    # @param [#realpath, #to_s] pathname_or_remote_url
    # @param [Hash] options
    # @option options [String] :username
    # @option options [String] :password
    # @option options [String] :ssh_passphrase
    # @option options [Boolean] :force
    # @option options [Pathname, String, Array<String>] :directory
    #
    # @overload clone(pathname_or_remote_url, *local_pathname, options)
    # @param [#realpath, #to_s] pathname_or_remote_url
    # @param [Pathname, String, Array<String>] *local_pathname
    # @param [Hash] options
    # @option options [String] :username
    # @option options [String] :password
    # @option options [String] :ssh_passphrase
    # @option options [Boolean] :force
    # @option options [Pathname, String, Array<String>] :directory
    #
    # @return [Array(Pathname, Hash)]
    def self.process_clone_args(pathname_or_remote_url, *args)
      local_pathname_parts, options = Utils.split_options(args)

      local_pathname =
        # Find a base name if a pathname_parts are empty.
        if local_pathname_parts.empty?
          basename =
            if pathname_or_remote_url.respond_to?(:basename)
              pathname_or_remote_url.basename('.git')
            else
              File.basename(
                Utils.git_clone_url(pathname_or_remote_url).path,
                '.git'
              )
            end
          Utils.to_pathname(options[:directory], basename)
        else
          Utils.to_pathname(options[:directory], local_pathname_parts)
        end

      [local_pathname, options]
    end
  end
end
