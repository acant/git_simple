class GitFactory
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
  end

  # @param [Pathname] repository_pathname
  # @yield Block which be executed in the DSL context
  #
  # @return [void]
  def self.build(repository_pathname, &block)
    instance = new(repository_pathname)
    instance.instance_eval(&block)
  end

  # @param (see .build)
  # @param [Hash] options
  # @option options [Boolean] :force
  #
  # @raise if the directory already exists and not forced
  #
  # @return (see .build)
  def self.init(repository_pathname, options = {}, &block)
    if options[:force]
      repository_pathname.rmtree if repository_pathname.directory?
      repository_pathname.delete if repository_pathname.file?
    end

    if repository_pathname.exist?
      raise(
        "GitFactory cannot init #{repository_pathname} because it alredy exists"
      )
    end

    repository_pathname.mkpath
    Rugged::Repository.init_at(repository_pathname.to_s)

    build(repository_pathname, &block)
  end

  # @param (see .init)
  def self.init_f(repository_pathname, options = {}, &block)
    options[:force] = true
    init(repository_pathname, options, &block)
  end

  # @param [Pathname]
  def initialize(repository_pathname)
    @repository_pathname = repository_pathname
  end

  # @overload write(*paths)
  #   @param [Array<String>] *paths
  #
  # @overload write(*paths, options)
  #   @param [Array<String>] *paths
  #   @param [Hash] options
  #   @option options [String] :string
  #
  # @return [void]
  def write(*paths_and_options)
    paths   = paths_and_options
    options = paths.last.is_a?(Hash) ? paths.pop : {}

    pathname = @repository_pathname.join(*paths)
    pathname.dirname.mkpath
    IO.write(pathname.to_s, options[:string] || '')
    # TODO: Convert back to Pathname#write after Ruby v2.0.0 support is dropped.
    # pathname.write(options[:string] || '')
  end

  # @param (see #write)
  #
  # @ return [void]
  def add(*paths_and_options)
    write(*paths_and_options)

    paths = paths_and_options
    paths.pop if paths.last.is_a?(Hash)
    rugged_repository.index.add(Pathname('').join(*paths).to_s)
  end

  # @param [String] message
  # @param [Hash] options
  # @option options [String] :name
  # @option options [String] :email
  #
  # @return [void]
  def commit(message, options = {}) # rubocop;disable Metrics/AbcSize
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
    rugged_repository.index.reload
    rugged_repository.index.add_all
    rugged_repository.index.update_all
    rugged_repository.index.write

    commit(message, options)
  end

  # @param [Array<String>] *paths
  #
  # @return [void]
  def delete(*paths)
    @repository_pathname.join(*paths).delete
  end

  ##############################################################################

  private

  # @return [Rugged::Repository]
  def rugged_repository
    @rugged_repository ||= Rugged::Repository.new(@repository_pathname.to_s)
  end

  # @return [Array<Rugged::Commit>]
  def parent_commits
    return [] if rugged_repository.empty?
    [rugged_repository.head.target].compact
  end
end
