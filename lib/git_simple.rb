require 'git_simple/version'
require 'git_simple/utils'
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

  # @param [#realpath, #to_s] pathname_or_remote_url
  #
  # @return [Git::Simple]
  def clone(pathname_or_remote_url)
    remote_url =
      if pathname_or_remote_url.respond_to?(:realpath)
        "file://#{pathname_or_remote_url.realpath}"
      else
        pathname_or_remote_url.to_s
      end

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
  # @raise (see #commit_create)
  #
  # @return [Git::Simple]
  def commit(message, options = {})
    index_write do
      commit_create(
        message,
        rugged.index.write_tree,
        head_target,
        options
      )
    end
  end

  # @param [Hash] options
  # @option options [String] :name for the author and committer
  # @option options [String] :email for the author and committer
  #
  # @raise (see #commit_create)
  #
  # @return [Git::Simple]
  def pull(options = {}) # rubocop:disable Metrics/AbcSize
    head_remote.fetch

    merge_analysis = rugged.merge_analysis(head_remote_branch.name)
    if merge_analysis.include?(:fastforward)
      rugged.references.update(head_ref, head_remote_branch.target_id)
      rugged.checkout_head(strategy: :force)
    elsif merge_analysis.include?(:normal)
      ours   = head_target
      theirs = head_remote_branch.target
      base   = rugged.rev_parse(rugged.merge_base(ours, theirs))
      index  = ours.tree.merge(theirs.tree, base.tree)

      commit_create(
        "Merge branch '#{head_branch.name}' of #{head_remote.url}",
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
    return self unless head_remote

    head_remote.push([head_ref])
    self
  end

  # Allow direct access to the Rugged object.
  #
  # @yieldparam [Rugged] rugged
  # @yieldparam [Pathname] working_directory
  #
  # @return [Git::Simple]
  def bypass
    yield(rugged, working_directory)
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
    return [] unless head_target

    path = args.any? ? Utils.to_pathname(*args).to_s : nil

    walker = Rugged::Walker.new(rugged)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(head_target)
    walker.select { |x| path.nil? || x.diff(paths: [path]).size.nonzero? }
  end

  # @return [String]
  def inspect
    result = "Working directory: #{working_directory}\n"
    result << '  HEAD:'
    begin
      result << " #{rugged.head.name}\n"
    rescue Rugged::ReferenceError
      result << " none\n"
    end

    result << 'Remotes:'
    if rugged.remotes.none?
      result << " none\n"
    else
      result << "\n"
      rugged.remotes.each { |x| result << "  * #{x.name} #{x.url}\n" }
    end

    result += 'Branches:'
    if rugged.branches.none?
      result << " none\n"
    else
      result << "\n"
      rugged.branches.each do |branch|
        result << "  * #{branch.name}"
        if branch.upstream
          result << " (upstream: #{branch.upstream.name})\n"
        else
          result << "\n"
        end
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

  # @return [Pathname]
  def working_directory
    Pathname.new(rugged.workdir)
  end

  # @return [nil]
  # @return [Rugged::Commit]
  def head_target
    return if rugged.empty?
    rugged.head.target
  end

  # @return [String]
  def head_ref
    rugged.head.name
  end

  # @return [Rugged::Branch]
  def head_branch
    rugged.branches[head_ref]
  end

  # @return [nil]
  # @return [Rugged::Remote]
  def head_remote
    head_branch.remote || rugged.remotes['origin']
  end

  # @return [nil]
  # @return [Rugged::Branch]
  def head_remote_branch
    head_branch.upstream || rugged.branches["#{head_remote.name}/#{head_branch.name}"]
  end

  # @param [Hash] options
  # @option options [String] :name for the author and committer
  # @option options [String] :email for the author and committer
  #
  # @raise [GitSimple::Error] if name or email cannot be found
  #
  # @return [Hash]
  def author_now(options = {})
    result = {
      name:  options[:name] || rugged.config['user.name'],
      email: options[:email] || rugged.config['user.email'],
      time:  Time.now
    }
    raise(GitSimple::Error, 'Cannot commit without a user name') unless result[:name]
    raise(GitSimple::Error, 'Cannot commit without a user email') unless result[:email]

    result
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
      rugged,
      tree:       tree,
      author:     author,
      committer:  author,
      message:    message,
      parents:    [parents].flatten.compact,
      update_ref: 'HEAD'
    )
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
      Utils.glob_to_pathnames(
        args, working_directory.realpath
      ) do |relative_path, realpath|
        yield(index, relative_path, realpath)
      end
    end
  end
end

def GitSimple(*args) # rubocop:disable Naming/MethodName
  GitSimple.new(*args)
end
