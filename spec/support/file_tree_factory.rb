class FileTreeFactory
  class << self
    # @param [Pathname] root_pathname
    # @yield Block which be executed in the DSL context
    #
    # @return [void]
    def append(root_pathname, &block)
      instance = new(root_pathname)
      instance.instance_eval(&block) if block
    end

    # Clear the existing file tree before executing the commands in the block.
    #
    # @param [Pathname] root_pathname
    # @yield Block which be executed in the DSL context
    #
    # @return [void]
    def create(root_pathname, &block)
      instance = new(root_pathname)
      instance.clear
      instance.instance_eval(&block) if block
    end
  end

  # @param [Pathname] root_pathname
  def initialize(root_pathname)
    @root_pathname = root_pathname
  end

  # @return [void]
  def clear
    @root_pathname.rmtree if @root_pathname.directory?
    @root_pathname.delete if @root_pathname.file?

    if @root_pathname.exist?
      raise(
        "#{self.class} cannot create #{@root_pathname} because it alredy exists"
      )
    end

    @root_pathname.mkpath
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

    pathname = @root_pathname.join(*paths)
    pathname.dirname.mkpath
    IO.write(pathname.to_s, options[:string] || '')
    # TODO: Convert back to Pathname#write after Ruby v2.0.0 support is dropped.
    # pathname.write(options[:string] || '')
  end

  # @param [Array<String>] *paths
  #
  # @return [void]
  def delete(*paths)
    @root_pathname.join(*paths).delete
  end
end
