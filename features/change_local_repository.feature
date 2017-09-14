Feature: Change commits the local repository

Background:
  Given the local repository exists

Scenario: Make commit a file to a repository
  When I execute:
    """ruby
    new_file_pathname = local_repository_pathname.join('new_file')
    new_file_pathname.write('add')
    local_git.add(new_file_pathname)
    local_git.commit('add file commit')
    """
  Then I see a commit message 'add file commit'
    And I see everything is committed

Scenario: Remove a file from the repository

Scenario: Make a commit with everything the working tree
  When I execute:
    """ruby
    existing_file_pathname = local_repository_pathname.join('existing_file')
    local_git.rm(existing_file_pathname)
    local_git.commit('rm file local')
    """
  Then I see a commit message 'add file commit'
    And I see everything is committed

