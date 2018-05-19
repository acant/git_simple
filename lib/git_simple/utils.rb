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
  end
end
