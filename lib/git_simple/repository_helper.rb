class GitSimple
  # Common helper code for using the Rugged::Repository.
  class RepositoryHelper
    # @param [Rugged::Repository] rugged
    def initialize(rugged)
      @rugged = rugged
    end

    # @return [nil]
    # @return [Rugged::Commit]
    def head_target
      @rugged.head.target
    rescue Rugged::ReferenceError
      nil
    end

    # @return [String]
    def head_ref
      @rugged.head.name
    rescue Rugged::ReferenceError
      'refs/heads/master'
    end

    # @return [nil]
    # @return [Rugged::Branch]
    def head_branch
      @rugged.branches[head_ref]
    end

    # @return [nil]
    # @return [Rugged::Remote]
    def head_remote
      remote_origin = @rugged.remotes['origin']

      return remote_origin unless head_branch
      head_branch.remote || remote_origin
    end

    # @return [nil]
    # @return [Rugged::Branch]
    def head_remote_branch
      return unless head_remote
      return @rugged.branches["#{head_remote.name}/master"] unless head_branch
      head_branch.upstream || @rugged.branches["#{head_remote.name}/#{head_branch.name}"]
    end

    # @param [String] message
    # @param [Rugged::Tree]  tree
    # @param [Rugged::Commit, Array<Rugged::Commit>] parents
    # @param [Hash] options
    # @option options [String] :name for the author and committer
    # @option options [String] :email for the author and committer
    #
    # @raise (see #author_now)
    #
    # @return [Rugged::Commit]
    def commit_create(message, tree, parents, options = {})
      author = author_now(options)
      Rugged::Commit.create(
        @rugged,
        tree:       tree,
        author:     author,
        committer:  author,
        message:    message,
        parents:    [parents].flatten.compact,
        update_ref: 'HEAD'
      )
    end

    # @return [Pathname]
    def working_directory
      Pathname.new(@rugged.workdir)
    end

    # "Open" the index for writing by reloading it, and the ensure that the
    # modified index is written out to disk right away.
    #
    # @yieldparam [Rugged::Index] index
    #
    # @return [void]
    def index_write
      @rugged.index.reload
      yield(@rugged.index)
      @rugged.index.write
    end

    # Glob the args and open the index for writing at the same time.
    #
    # @param [Array<String, Array<String>, Pathname>] *args
    # @yieldparam [Rugged::Index] index
    # @yieldparam [Pathname] relative_path
    # @yieldparam [Pathname] realpath
    #
    # @return [void]
    def glob_to_index(args)
      index_write do |index|
        Utils.each_with_glob(
          args, working_directory.realpath
        ) do |relative_path, realpath|
          yield(index, relative_path, realpath)
        end
      end
    end

    ############################################################################

    private

    # @param [Hash] options
    # @option options [String] :name for the author and committer
    # @option options [String] :email for the author and committer
    #
    # @raise [GitSimple::Error] if name or email cannot be found
    #
    # @return [Hash]
    def author_now(options = {})
      result = {
        name:  options[:name] || @rugged.config['user.name'],
        email: options[:email] || @rugged.config['user.email'],
        time:  Time.now
      }
      raise(GitSimple::Error, 'Cannot commit without a user name') unless result[:name]
      raise(GitSimple::Error, 'Cannot commit without a user email') unless result[:email]

      result
    end
  end
end
