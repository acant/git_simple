Feature: View information about the repository

Background:
  Given a local repository
    And 'existing1' is committed
    And 'existing2' is committed

Scenario: View the log
  When I execute:
    """ruby
      GitSimple(local_repository_pathname).log.map(&:to_hash)
    """
  Then I see the output includes:
    """ruby
      [
        { message: 'filename existing2 commit' },
        { message: 'filename existing1 commit' }
      ]
    """

Scenario: View the log for a particular path
  When I execute:
    """ruby
      GitSimple(local_repository_pathname).log('existing2').map(&:to_hash)
    """
  Then I see the output includes:
    """ruby
      [{ message: 'filename existing2 commit' }]
    """

Scenario: View if there are uncommitted changes
  Given has uncommitted files:
    |new|
    |other|
  When I execute:
    """ruby
      GitSimple(local_repository_pathname).clean?
    """
  Then I see the output: false

Scenario: List remotes
  Given a remote called 'remote1'
    And a remote called 'remote2'
  When I execute:
    """ruby
      GitSimple(local_repository_pathname).remote_names
    """
  Then I see the output: %w[remote1 remote2]

Scenario: List branches
  Given a branch called 'branch1'
    And a branch called 'branch2'
  When I execute:
    """ruby
      GitSimple(local_repository_pathname).branch_names
    """
  Then I see the output: %w[branch1 branch2 master]
