require 'git_simple/version'
require 'git_simple/utils'
require 'rugged'

# Simple interface for interacting with a Git repository.
#
# @example
#
#   GitSimple.new('repo')
#     .add('new_file')
#     .rm('old_file')
#     .commit('Made some changes', name: 'Art T. Fish', email: 'afish@example.com')
class GitSimple
  # @param (see Git::Simple::Utils.to_pathname)
  def initialize(*args)
    @repository_pathname = Utils.to_pathname(*args)
  end

  # Add files into the index.
  #
  # @see https://github.com/hx/rugged-easy/blob/master/lib/rugged/easy/repository.rb
  #
  # @param [Array<String, Array<String>, Pathname>] *args
  #
  # @return [Git::Simple]
  def add(*args)
    glob_to_index(args) do |index, relative_path|
      index.add(relative_path.to_s)
    end
  end

  # Add all changes in the working tree into the index.
  #
  # @return [Git::Simple]
  def add_all
    index_write do |index|
      index.add_all
      index.update_all
    end
  end

  # Remove files from the working tree and the index
  #
  # @param [Array<String, Array<String>, Pathname>] *args
  #
  # @return [Git::Simple]
  def rm(*args)
    glob_to_index(args) do |index, relative_path, realpath|
      index.remove(relative_path.to_s)
      realpath.delete
    end
  end

  # @param [String] message
  # @param [Hash] options
  # @option options [String] :name for the author and committer
  # @option options [String] :email for the author and committer
  #
  # @return [Git::Simple]
  def commit(message, options = {})
    author_hash = {
      name:  options[:name],
      email: options[:email],
      time:  Time.now
    }
    rugged.index.reload
    Rugged::Commit.create(
      rugged,
      tree:       rugged.index.write_tree(rugged),
      author:     author_hash,
      committer:  author_hash,
      message:    message,
      parents:    [last_commit].compact,
      update_ref: 'HEAD'
    )

    self
  end

  ############################################################################

  private

  # @return [Rugged::Repository]
  def rugged
    @rugged ||= Rugged::Repository.new(@repository_pathname.to_s)
  end

  # @return [Pathname]
  def repository_realpath
    @repository_pathname.realpath
  end

  # @return [nil]
  # @return [Rugged::Commit]
  def last_commit
    return if rugged.empty?
    rugged.head.target
  end

  # "Open" the index for writing by reloading it, and the ensure that the
  # modified index is written out to disk right away.
  #
  # @yieldparam [Rugged::Index] index
  #
  # @return [GitSimple]
  def index_write
    rugged.index.reload
    yield(rugged.index)
    rugged.index.write

    self
  end

  # Glob the args and open the index for writing at the same time.
  #
  # @param [Array<String, Array<String>, Pathname>] *args
  # @yieldparam [Rugged::Index] index
  # @yieldparam [Pathname] relative_path
  # @yieldparam [Pathname] realpath
  #
  # @return [GitSimple]
  def glob_to_index(args)
    index_write do |index|
      Utils.glob_to_pathnames(args, repository_realpath) do |relative_path, realpath|
        yield(index, relative_path, realpath)
      end
    end
  end
end
