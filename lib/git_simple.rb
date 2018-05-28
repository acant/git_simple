require 'git_simple/version'
require 'git_simple/utils'
require 'git_simple/repository_helper'
require 'rugged'
require 'git_clone_url'
require 'grit'
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
  class Error < StandardError; end
  class MergeConflict < Error; end
  class NoCommonCommit < Error; end
  class PushError < Error; end

  # @param [#realpath, #to_s] pathname_or_remote_url
  # @param [Hash] options
  # @option options [String] :username
  # @option options [String] :password
  # @option options [String] :ssh_passphrase
  # @option options [Boolean] :force
  #
  # @return [Git::Simple]
#  def self.clone(pathname_or_remote_url, options = {})
#    new()
#  end

  # @param (see .clone)
  #
  # @return (see .clone)
#  def self.clone_f(pathname_or_remote_url, options = {})
#    clone
#  end

  # @param (see Git::Simple::Utils.to_pathname)
  def initialize(*args)
    @pathname = Utils.to_pathname(*args)
  end

  # @return [Git::Simple]
  def init
    Rugged::Repository.init_at(@pathname.to_s)
    self
  end

  # @param [#realpath, #to_s] pathname_or_remote_url
  # @param [Hash] options
  # @option options [String] :username
  # @option options [String] :password
  # @option options [String] :ssh_passphrase
  # @option options [Boolean] :force
  #
  # @return [Git::Simple]
  def clone(pathname_or_remote_url, options = {})
    remote_url =
      if pathname_or_remote_url.respond_to?(:realpath)
        "file://#{pathname_or_remote_url.realpath}"
      else
        pathname_or_remote_url.to_s
      end

    @pathname.rmtree if options[:force] && @pathname.directory?

    @pathname.mkpath
    Rugged::Repository.clone_at(
      remote_url,
      @pathname.to_s,
      Utils.build_remote_options(remote_url, options)
    )
    self
  end

  # @param (see #clone)
  # @return (see #clone)
  def clone_f(pathname_or_remote_url, options = {})
    clone(pathname_or_remote_url, options.merge(force: true))
  end

  # Add files into the index.
  #
  # @see https://github.com/hx/rugged-easy/blob/master/lib/rugged/easy/repository.rb
  #
  # @param [Array<String, Array<String>, Pathname>] *args
  #
  # @return [Git::Simple]
  def add(*args)
    helper.glob_to_index(args) do |index, relative_path|
      index.add(relative_path.to_s)
    end

    self
  end

  # Add all changes in the working tree into the index.
  #
  # @return [Git::Simple]
  def add_all
    helper.index_write do |index|
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
    helper.glob_to_index(args) do |index, relative_path, realpath|
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
  # @raise (see #commit_create)
  #
  # @return [Git::Simple]
  def commit(message, options = {})
    helper.index_write do
      helper.commit_create(
        message,
        rugged.index.write_tree,
        helper.head_target,
        options
      )
    end

    self
  end

  # @param [Rugged::Branch] merge_branch
  #
  # @raise GitSimple::MergeConflict
  # @raise GitSimple::NoCommonCommit
  #
  # @return [Git::Simple]
  def merge(merge_branch, options = {})
    merge_analysis = rugged.merge_analysis(merge_branch.name)
    if merge_analysis.include?(:fastforward)
      rugged.references.update(helper.head_ref, merge_branch.target_id)
      rugged.checkout_head(strategy: :force)
    elsif merge_analysis.include?(:normal)
      ours       = helper.head_target
      theirs     = merge_branch.target
      merge_base = rugged.merge_base(ours, theirs)
      raise(NoCommonCommit) unless merge_base

      base  = rugged.rev_parse(merge_base)
      index = ours.tree.merge(theirs.tree, base.tree)

      commit_message =
        if index.conflicts?
          raise(MergeConflict) unless block_given?

          message = yield(index, rugged, helper.working_directory)
          raise(MergeConflict) unless message

          index.conflict_cleanup
          message
        else
          "Merge branch '#{helper.head_branch.name}' of #{helper.head_remote.url}"
        end

      helper.commit_create(
        commit_message,
        index.write_tree(rugged),
        [ours, theirs],
        options
      )
      rugged.checkout_head(strategy: :force)
    end

    self
  end

  # @param [Hash] options
  # @option options [String] :name for the author and committer
  # @option options [String] :email for the author and committer
  # @option options [String] :username
  # @option options [String] :password
  # @option options [String] :ssh_passphrase
  #
  # @yieldparam [Rugged::Index] merge_index
  # @yieldparam [Rugged] rugged
  # @yieldparam [Pathname] working_directory
  #
  # @raise GitSimple::MergeConflict
  # @raise GitSimple::NoCommonCommit
  # @raise (see #commit_create)
  #
  # @return [Git::Simple]
  def pull(options = {}, &block)
    return self unless helper.head_remote
    helper.head_remote.fetch(
      Utils.build_remote_options(helper.head_remote, options)
    )

    return self unless helper.head_remote_branch

    unless helper.head_branch
      rugged.checkout(helper.head_remote_branch)
      return self
    end

    merge(helper.head_remote_branch, options, &block)

    # FIXME: Until a rugged/libgit2 re-implementation of automatic garbage
    # collection is created or available, the gc command which is built-in to
    # standard git must be used. Instead of temporarily re-implmentig it the
    # existing grit implementation can be used. Even through it is no longer
    # maintained, it is good enough when it will be replaced soon.
    #
    # @see https://git-scm.com/docs/git-gc
    # @see https://github.com/mojombo/grit/blob/5608567286e64a1c55c5e7fcd415364e04f8986e/lib/grit/repo.rb#L645
    Grit::Repo.new(rugged.workdir).gc_auto

    self
  end

  # @param [Hash] options
  # @option options [String] :username
  # @option options [String] :password
  # @option options [String] :ssh_passphrase
  #
  # @return [Git::Simple]
  def push(options = {})
    return self if rugged.empty?
    return self unless helper.head_remote

    helper.head_remote.push(
      [helper.head_ref],
      Utils.build_remote_options(helper.head_remote, options)
    )
    self
  rescue Rugged::Error => exception
    raise(PushError, exception.message)
  end

  # Allow direct access to the Rugged object.
  #
  # @yieldparam [Rugged] rugged
  # @yieldparam [Pathname] working_directory
  #
  # @return [Git::Simple]
  def bypass
    yield(rugged, helper.working_directory)
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
    return [] unless helper.head_target

    path = args.any? ? Utils.to_pathname(*args).to_s : nil

    walker = Rugged::Walker.new(rugged)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(helper.head_target)
    walker.select { |x| path.nil? || x.diff(paths: [path]).size.nonzero? }
  end

  # @return [String]
  def inspect # rubocop:disable Metrics/AbcSize
    result = "Working directory: #{helper.working_directory}\n"
    result << "  HEAD: #{helper.head_ref}\n"

    result << 'Remotes:'
    if rugged.remotes.none?
      result << " none\n"
    else
      result << "\n"
      rugged.remotes.each { |x| result << "  * #{x.name} #{x.url}\n" }
    end

    result << 'Branches:'
    if rugged.branches.none?
      result << " none\n"
    else
      result << "\n"
      rugged.branches.each do |branch|
        result << "  * #{branch.name}"
        result << " (upstream: #{branch.upstream.name})" if branch.upstream
        result << "\n"
      end
    end

    result
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

  # @return [Rugged::Repository]
  def rugged
    @rugged ||= Rugged::Repository.discover(@pathname.to_s)
  end

  # @return [GitSimple::RepositoryHelper]
  def helper
    @helper ||= RepositoryHelper.new(rugged)
  end
end

def GitSimple(*args) # rubocop:disable Naming/MethodName
  GitSimple.new(*args)
end
