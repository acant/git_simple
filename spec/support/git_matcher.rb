RSpec::Matchers.define :be_a_repository do
  match do |actual|
    begin
      Rugged::Repository.new(actual.to_s)
      true
    rescue # rubocop:disable Lint/RescueWithoutErrorClass
      false
    end
  end
end

RSpec::Matchers.define :have_indexed do |expected|
  match do |actual|
    actual_rugged_repository = Rugged::Repository.new(actual.to_s)
    !actual_rugged_repository.index[expected].nil?
  end
end

RSpec::Matchers.define :have_any_changes do
  match { |actual| diff_workdir_deltas(actual).any? }

  match_when_negated { |actual| diff_workdir_deltas(actual).empty? }

  def diff_workdir_deltas(actual)
    actual_rugged_repository = Rugged::Repository.new(actual.to_s)
    current_oid =
      begin
        actual_rugged_repository.head.target_id
      rescue Rugged::ReferenceError
        nil
      end

    if current_oid
      actual_rugged_repository.diff_workdir(
        current_oid, include_untracked: false
      ).deltas
    else
      []
    end
  end
end

RSpec::Matchers.define :have_commit_count do
  match do |actual|
    begin
      repository = Rugged::Repository.new(actual.to_s)
      if repository.empty?
        0
      else
        walker = Rugged::Walker.new(repository)
        walker.sorting(Rugged::SORT_DATE)
        walker.push(repository.head.target)
        count = 0
        walker.each { count += 1 }
        count
      end
    rescue # rubocop:disable Lint/RescueWithoutErrorClass
      0
    end
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

    @actual = {}
    # rubocop:disable Metrics/LineLength
    @actual[:message]         = commit.message                if @expected.key?(:message)
    @actual[:author_at]       = norm(commit.author[:time])    if @expected.key?(:author_at)
    @actual[:author_name]     = commit.author[:name]          if @expected.key?(:author_name)
    @actual[:author_email]    = commit.author[:email]         if @expected.key?(:author_email)
    @actual[:committer_at]    = norm(commit.committer[:time]) if @expected.key?(:committer_at)
    @actual[:committer_name]  = commit.committer[:name]       if @expected.key?(:committer_name)
    @actual[:committer_email] = commit.committer[:email]      if @expected.key?(:committer_email)
    # rubocop:enable all

    next false unless commit
    @actual == @expected
  end

  chain :with_message do |expected|
    @expected ||= {}
    @expected[:message] = expected
  end

  chain :at do |expected|
    @expected ||= {}
    @expected[:author_at]    = norm(expected)
    @expected[:committer_at] = norm(expected)
  end

  chain :by do |expected_name, expected_email|
    @expected ||= {}
    @expected[:author_name]     = expected_name
    @expected[:author_email]    = expected_email
    @expected[:committer_name]  = expected_name
    @expected[:committer_email] = expected_email
  end

  diffable
  attr_reader :actual, :expected

  # Normalize Time, by clearing sub-second elements.
  #
  # @param [Time] time
  #
  # @return [Time]
  def norm(time)
    Time.new(time.to_i)
  end
end

RSpec::Matchers.define :be_synchronized_with do |expected|
  match do |actual|
    actual_rugged_repository = Rugged::Repository.new(actual.to_s)
    actual_current_oid =
      begin
        actual_rugged_repository.head.target_id
      rescue Rugged::ReferenceError
        nil
      end

    expected_rugged_repository = Rugged::Repository.new(expected.to_s)
    expected_current_oid =
      begin
        expected_rugged_repository.head.target_id
      rescue Rugged::ReferenceError
        nil
      end

    @actual =
      if actual_rugged_repository.empty?
        'no commits in repository'
      else
        begin
          if actual_rugged_repository.head.target.nil?
            'no commits at head'
          else
            actual_walker = Rugged::Walker.new(actual_rugged_repository)
            actual_walker.sorting(Rugged::SORT_DATE)
            actual_walker.push(actual_rugged_repository.head.target)
            message = ''
            actual_walker.each { |x| message += "#{x.oid} #{x.message}\n" }
            message
          end
        rescue Rugged::ReferenceError
          'no head checked out'
        end
      end

    @expected =
      if expected_rugged_repository.empty?
        'no commits in repository'
      else
        begin
          if expected_rugged_repository.head.target.nil?
            'no commits at head'
          else
            expected_walker = Rugged::Walker.new(expected_rugged_repository)
            expected_walker.sorting(Rugged::SORT_DATE)
            expected_walker.push(expected_rugged_repository.head.target)
            message = ''
            expected_walker.each { |x| message += "#{x.oid} #{x.message}\n" }
            message
          end
        rescue Rugged::ReferenceError
          'no head checked out'
        end
      end

    actual_current_oid == expected_current_oid
  end

  diffable
  attr_reader :actual, :expected
end
