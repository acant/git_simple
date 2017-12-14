Feature: Synchronize remote repositories

Scenario Outline: Synchronize without any changes
  Given a remote repository accessible by <protocol>
    And 'initial_commit' is committed in the remote repository
    And a local clone
  When I execute:
    """ruby
      GitSimple(local_repository_pathname)
       .add_all
       .commit('add file')
       .pull
       .push
    """
  Then I see the repositories are synchronized
  Examples:
    | protocol |
    | file     |
    | http     |
    | https    |
    | ssh      |

Scenario Outline: Synchronize with remote changes
  Given a remote repository accessible by <protocol>
    And 'initial_commit' is committed in the remote repository
    And a local clone
    And 'remote_commit' is committed in the remote repository
  When I execute:
    """ruby
      GitSimple(local_repository_pathname)
       .add_all
       .commit('add file')
       .pull
       .push
    """
  Then I see the repositories are synchronized
  Examples:
    | protocol |
    | file     |
    | http     |
    | https    |
    | ssh      |

Scenario Outline: Synchronize with local changes
  Given a remote repository accessible by <protocol>
    And 'initial_commit' is committed in the remote repository
    And a local clone
    And 'new_commit' is committed
    And has uncommitted files:
      |new|
  When I execute:
    """ruby
      GitSimple(local_repository_pathname)
       .add_all
       .commit('add file')
       .pull
       .push
    """
  Then I see the repositories are synchronized
  Examples:
    | protocol |
    | file     |
    | http     |
    | https    |
    | ssh      |

Scenario Outline: Synchronize changes in both repositories
  Given a remote repository accessible by <protocol>
    And 'initial_commit' is committed in the remote repository
    And a local clone
    And 'remote_commit' is committed in the remote repository
    And 'new_commit' is committed
    And has uncommitted files:
      |new|
  When I execute:
    """ruby
      GitSimple(local_repository_pathname)
       .add_all
       .commit('add file')
       .pull
       .push
    """
  Then I see the repositories are synchronized
  Examples:
    | protocol |
    | file     |
    | http     |
    | https    |
    | ssh      |
