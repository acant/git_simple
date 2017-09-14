RSpec::Matchers.define :have_indexed do |expected|
  match do |actual|
    actual_rugged_repository = Rugged::Repository.new(actual.to_s)
    !actual_rugged_repository.index[expected].nil?
  end
end

RSpec::Matchers.define :have_removed do |expected|
  match do |actual|
    actual_rugged_repository = Rugged::Repository.new(actual.to_s)
    diff_workdir_deltas =
      actual_rugged_repository.diff_workdir(
        actual_rugged_repository.head.target_id, include_untracked: true
      ).deltas

    next false if actual.join(expected).exist?
    diff_workdir_deltas.any? { |x| x.old_file[:path] == expected && x.status == :deleted }
  end

  match_when_negated do |actual|
    actual_rugged_repository = Rugged::Repository.new(actual.to_s)

    next false unless actual.join(expected).exist?
    !actual_rugged_repository.index[expected].nil?
  end
end

RSpec::Matchers.define :have_commit do |expected_commit|
  match do |actual|
    actual_rugged_repository = Rugged::Repository.new(actual.to_s)

    next false unless actual_rugged_repository.head
    next false unless actual_rugged_repository.head.target

    walker = Rugged::Walker.new(actual_rugged_repository)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(actual_rugged_repository.head.target)
    result = []
    walker.each { |x| result.push(x) }

    commit_index =
      case expected_commit
      when :head then 0
      when :head1 then 1
      when :head2 then 2
      else
        expected_commit.to_i
      end
    commit = result[commit_index]

    !commit.nil? &&
      commit.message               == @expected_message &&
      commit.author[:name]         == @expected_attributes[:name] &&
      commit.author[:email]        == @expected_attributes[:email] &&
      commit.author[:time].to_i    == @expected_time.to_i &&
      commit.committer[:name]      == @expected_attributes[:name] &&
      commit.committer[:email]     == @expected_attributes[:email] &&
      commit.committer[:time].to_i == @expected_time.to_i
  end

  chain :with do |expected_message, expected_time, expected_attributes|
    @expected_message    = expected_message
    @expected_time       = expected_time
    @expected_attributes = expected_attributes
  end
end
