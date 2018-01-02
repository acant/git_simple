require 'git_simple/version'
require 'git_simple/utils'
require 'git_simple/rugged_wrapper'
require 'rugged'
require 'pathname'

# Simple interface for interacting with a Git repository.
#
# @example
#
#   GitSimple('repo')
#     .add('new_file')
#     .rm('old_file')
#     .commit('Made some changes', name: 'Art T. Fish', email: 'afish@example.com')
#
class GitSimple
  class Error < StandardError
  end

  # @param (see Git::Simple::Utils.to_pathname)
  def initialize(*args)
    @pathname = Utils.to_pathname(*args)
  end

  # @return [Git::Simple]
  def init
    Rugged::Repository.init_at(@pathname.to_s)
    self
  end

  # @param [String]
  #
  # @return [Git::Simple]
  def clone(remote_url)
    # raise if the pathname already exists
    @pathname.mkpath
    Rugged::Repository.clone_at(remote_url, @pathname.to_s)
    self
  end

  # Add files into the index.
  #
  # @see https://github.com/hx/rugged-easy/blob/master/lib/rugged/easy/repository.rb
  #
  # @param [Array<String, Array<String>, Pathname>] *args
  #
  # @return [Git::Simple]
  def add(*args)
    wrapper.glob_to_index(args) do |index, relative_path|
      index.add(relative_path.to_s)
    end
    self
  end

  # Add all changes in the working tree into the index.
  #
  # @return [Git::Simple]
  def add_all
    wrapper.index_write do |index|
      index.add_all
      index.update_all
    end
    self
  end

  # Remove files from the working tree and the index
  #
  # @param [Array<String, Array<String>, Pathname>] *args
  #
  # @return [Git::Simple]
  def rm(*args)
    wrapper.glob_to_index(args) do |index, relative_path, realpath|
      index.remove(relative_path.to_s)
      realpath.delete
    end
    self
  end

  # @param [String] message
  # @param [Hash] options
  # @option options [String] :name for the author and committer
  # @option options [String] :email for the author and committer
  #
  # @raise (see GitSimple::RuggedWrapper#commit_create)
  #
  # @return [Git::Simple]
  def commit(message, options = {})
    wrapper.index_write do
      wrapper.commit_create(
        message,
        rugged.index.write_tree,
        wrapper.head_target,
        options
      )
    end
    self
  end

  # @param [Hash] options
  # @option options [String] :name for the author and committer
  # @option options [String] :email for the author and committer
  #
  # @raise (see GitSimple::RuggedWrapper#commit_create)
  #
  # @return [Git::Simple]
  def pull(options = {}) # rubocop:disable Metrics/AbcSize
    return self unless wrapper.head_remote

    wrapper.head_remote.fetch

    return self unless wrapper.head_branch

    merge_analysis = rugged.merge_analysis(wrapper.head_remote_branch.name)
    if merge_analysis.include?(:fastforward)
      rugged.references.update(wrapper.head_ref, wrapper.head_remote_branch.target_id)
      rugged.checkout_head(strategy: :force)
    elsif merge_analysis.include?(:normal)
      ours   = wrapper.head_target
      theirs = wrapper.head_remote_branch.target
      base   = rugged.rev_parse(rugged.merge_base(ours, theirs))
      index  = ours.tree.merge(theirs.tree, base.tree)

      wrapper.commit_create(
        "Merge branch '#{wrapper.head_branch.name}' of #{wrapper.head_remote.url}",
        index.write_tree(rugged),
        [ours, theirs],
        options
      )
      rugged.checkout_head(strategy: :force)
    end

    self
  end

  # @return [Git::Simple]
  def push
    return self unless wrapper.head_remote

    wrapper.head_remote.push([wrapper.head_ref])
    self
  end

  # Allow direct access to the Rugged object.
  #
  # @yieldparam [Rugged] rugged
  # @yieldparam [Pathname] working_directory
  #
  # @return [Git::Simple]
  def bypass
    yield(rugged, wrapper.working_directory)
    self
  end

  # @overload log
  #
  # @overload log(path)
  #   @param [Pathname, String] path
  #
  # @overload log(*path)
  #   @param [Array<Pathname, String> *path
  #
  # @return [Enumerable<Rugged::Commit>]
  def log(*args)
    return [] unless wrapper.head_target

    path = args.any? ? Utils.to_pathname(*args).to_s : nil

    walker = Rugged::Walker.new(rugged)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(wrapper.head_target)
    walker.select { |x| path.nil? || x.diff(paths: [path]).size.nonzero? }
  end

  # @return [Array<String>]
  def remote_names
    rugged.remotes.map(&:name)
  end

  # @return [Array<String>]
  def branch_names
    rugged.branches.map(&:name)
  end

  # @return [Boolean]
  def clean_working_tree?
    rugged.status do |_file, status|
      next if status.include?(:ignored)
      return false
    end
    true
  end

  alias clean? clean_working_tree?

  ############################################################################

  private

  # @return [GitSimple::RuggedWrapper]
  def wrapper
    @rugged_wrapper ||= RuggedWrapper.new(@pathname)
  end

  # @return [Rugged::Repository]
  def rugged
    wrapper.rugged
  end
end

def GitSimple(*args) # rubocop:disable Naming/MethodName
  GitSimple.new(*args)
end
