Feature: Start a local repository

Scenario: Initialize a new working directory

Scenario: Clone from a repository over file
  Given a remote repository
  When I execute:
    """ruby
    git_simple = GitSimple(local_repository_pathname)
    git_simple.clone(remote_repository_file_url)
    """
  Then I see the repositories are synchronized

Scenario: Clone from a repository over HTTP

Scenario: Clone from a repository over HTTPS

Scenario: Clone from a repository over SSH
