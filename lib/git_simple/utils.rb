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
  end
end
