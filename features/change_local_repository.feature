Feature: Change commits the local repository

Background:
  Given a local repository
    And 'existing' is committed
    And has uncommitted files:
      |new|
      |other|

Scenario: Make commit a file to a repository
  When I execute:
    """ruby
    GitSimple(local_repository_pathname)
      .add('new')
      .commit('add file commit', name: 'Art T. Fish', email: 'afish@example.com')
    """
  Then I see a commit with 'add file commit'
    And I see everything is committed except 'other'

Scenario: Remove a file from the repository
  When I execute:
    """ruby
    GitSimple(local_repository_pathname)
      .rm('existing')
      .commit('remove file commit', name: 'Art T. Fish', email: 'afish@example.com')
    """
  Then I see a commit with 'remove file commit'
    And I see 'existing' is removed and deleted
    And I see everything is committed except:
      |new|
      |other|

Scenario: Make a commit with everything the working tree
  When the 'existing' file is deleted
    And I execute:
      """ruby
      GitSimple(local_repository_pathname)
        .add_all
        .commit('add all commit', name: 'Art T. Fish', email: 'afish@example.com')
      """
  Then I see a commit with 'add all commit'
    And I see everything is committed
