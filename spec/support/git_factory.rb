require Pathname(__FILE__).dirname.join('file_tree_factory.rb').to_s

class GitFactory < FileTreeFactory
  class << self
    attr_writer :default_name, :default_email

    # @return [String]
    def default_name
      return 'Art T. Fish' unless defined?(@default_name) && @default_name
      @default_name
    end

    # @return [String]
    def default_email
      return 'afish@example.com' unless defined?(@default_email) && @default_email
      @default_email
    end

    # Override the .create so that repository tree is cleared and then
    # initialized before executing the commands in the block.
    #
    # @overload create(root_pathname)
    #   @param [Pathname] root_pathname
    #   @yield Block which be executed in the DSL context
    #
    # @overload create(root_pathname, *init_args)
    #   @param [Pathname] root_pathname
    #   @param (see #init)
    #   @yield Block which be executed in the DSL context
    #
    # @return [void]
    def create(root_pathname, *init_args, &block)
      instance = new(root_pathname)
      instance.clear
      instance.init(*init_args)
      instance.instance_eval(&block) if block
    end
  end

  # @overload init
  #
  # @overload init(*args)
  #   @param [Array] args only a :bare is supported at the moment
  #
  # @return [void]
  def init(*args)
    Rugged::Repository.init_at(@root_pathname.to_s, *args)

    rugged_repository.config['user.name']  = GitFactory.default_name
    rugged_repository.config['user.email'] = GitFactory.default_email
  end

  # @param (see #write)
  #
  # @return [void]
  def add(*paths_and_options) # rubocop:disable Metrics/AbcSize
    paths    = paths_and_options.dup
    options  = paths.last.is_a?(Hash) ? paths.pop : {}
    filename = Pathname('').join(*paths).to_s

    if rugged_repository.bare?
      index_write do |index|
        index.add(
          path: filename,
          oid:  rugged_repository.write(options[:string] || '', :blob),
          mode: 0o100644
        )
      end
    else
      write(*paths_and_options)
      index_write { |index| index.add(filename) }
    end
  end

  # @param [Array<String>] *paths
  #
  # @return [void]
  def rm(*paths)
    filename = Pathname('').join(*paths).to_s

    index_write { |index| index.remove(filename) }
    delete(*paths)
  end

  # @param [String] message
  # @param [Hash] options
  # @option options [String] :name
  # @option options [String] :email
  #
  # @return [void]
  def commit(message, options = {}) # rubocop:disable Metrics/AbcSize
    rugged_repository.index.reload
    author_hash = {
      name:  options[:name] || GitFactory.default_name,
      email: options[:email] || GitFactory.default_email,
      time:  Time.now
    }
    Rugged::Commit.create(
      rugged_repository,
      tree:       rugged_repository.index.write_tree(rugged_repository),
      author:     author_hash,
      committer:  author_hash,
      message:    message,
      parents:    parent_commits,
      update_ref: 'HEAD'
    )
  end

  # @param (see #commit)
  #
  # @return [void]
  def commit_all(message, options = {})
    index_write do |index|
      index.add_all
      index.update_all
    end

    commit(message, options)
  end

  # @param [String] name
  # @param [String] url
  #
  # @return [void]
  def remote_create(name, url)
    rugged_repository.remotes.create(name, url)
  end

  # @overload ad
  def branch_create(name, starting_branch = 'master')
    rugged_repository.create_branch(
      name, rugged_repository.branches[starting_branch].target
    )
  end

  ##############################################################################

  private

  # @return [Rugged::Repository]
  def rugged_repository
    @rugged_repository ||= Rugged::Repository.new(@root_pathname.to_s)
  end

  # @return [Array<Rugged::Commit>]
  def parent_commits
    return [] if rugged_repository.empty?
    [rugged_repository.head.target].compact
  end

  # "Open" the index for writing by reloading it, and the ensure that the
  # modified index is written out to disk right away.
  #
  # @yieldparam [Rugged::Index]
  #
  # @return [void]
  def index_write
    rugged_repository.index.reload
    yield(rugged_repository.index)
    rugged_repository.index.write
  end
end
