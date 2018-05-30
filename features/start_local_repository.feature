Feature: Start a local repository

Scenario: Initialize a new working directory
  When I execute:
    """ruby
    GitSimple(local_repository_pathname)
      .init
    """
  Then I see a local repository

Scenario Outline: Clone from a remote repository
  Given a remote repository accessible by <protocol>
    And 'remote_commit' is committed in the remote repository
  When I execute:
    """ruby
    GitSimple.clone(<protocol_url>, local_repository_pathname)
    """
  Then I see the repositories are synchronized

  Examples:
    | protocol |
    | file     |
    | git      |
    | http     |
    | https    |
    | ssh      |

Scenario Outline: Force clone from a remote repository
  Given a remote repository accessible by <protocol>
    And 'remote_commit' is committed in the remote repository
    And a local repository
  When I execute:
    """ruby
    GitSimple.clone_f(<protocol_url>, local_repository_pathname)
    """
  Then I see the repositories are synchronized

  Examples:
    | protocol |
    | file     |
    | git      |
    | http     |
    | https    |
    | ssh      |
