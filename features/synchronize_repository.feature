Feature: Synchronize remote repositories

Scenario: Clone and push locally
  Given a remote repository
  When I execute:
    """ruby
    git_simple = GitSimple(local_repository_pathname)
    git_simple.clone(remote_repository_file_url)
    IO.write(local_repository_pathname.join('local_file').to_s, 'local_file')
    git_simple
      .add_all
      .commit('add file')
      .push
    """
  Then I see the repositories are synchronized

Scenario: Synchronize locally
  Given a remote repository
    And it is cloned locally
    And a new remote commit is added
  When I execute:
    """ruby
      IO.write(local_repository_pathname.join('local_file'), 'local_file')
      GitSimple(local_repository_pathname)
       .add_all
       .commit('add file')
       .pull
       .push
    """
  Then I see the repositories are synchronized

Scenario: Synchronize over HTTP
  Given the remote repository is available over HTTP

Scenario: Synchronize over HTTPS
  Given the remote repository is available over HTTPS

Scenario: Synchronize over SSH
  Given the remote repository is available over SSH
