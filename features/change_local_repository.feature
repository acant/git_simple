Feature: Change commits in the local repository

Background:
  Given a local repository
    And 'existing' is committed
    And has uncommitted files:
      |new|
      |other|

Scenario: Add a file to the repository
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

Scenario: Commit everything in the working tree
  When the 'existing' file is deleted
    And I execute:
      """ruby
      GitSimple(local_repository_pathname)
        .add_all
        .commit('add all commit', name: 'Art T. Fish', email: 'afish@example.com')
      """
  Then I see a commit with 'add all commit'
    And I see everything is committed

Scenario: Revert a single file
  Given 'existing' is committed with 'commit 2'
    And 'existing' is committed with 'commit 3'
  When I execute:
    """ruby
    GitSimple(local_repository_pathname)
      .bypass do |rugged, working_directory|
        blob = rugged.blob_at(rugged.head.target.parents.first.oid, 'existing')
        IO.write(working_directory.join('existing').to_s, blob.text) if blob
      end
    """
  Then I see 'existing' contains 'commit 2'
