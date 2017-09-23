FILE_REGEX = /'([^']+)'/

Given 'a local repository' do
  GitFactory.create(local_repository_pathname)
end

Given(/^#{FILE_REGEX} is committed$/) do |filename|
  GitFactory.append(local_repository_pathname) do
    add(filename)
    commit("filename #{filename} commit")
  end
end

Given(/^has uncommitted files:$/) do |table|
  GitFactory.append(local_repository_pathname) do
    table.raw.each { |row| write(row.first) }
  end
end

When(/^the #{FILE_REGEX} file is deleted$/) do |filename|
  GitFactory.append(local_repository_pathname) do
    delete(filename)
  end
end

When 'I execute:' do |script|
  expect { instance_eval(script) }.not_to raise_error
end

Then(/^I see a commit with #{FILE_REGEX}$/) do |message|
  expect(local_repository_pathname).to have_commit(:head)
    .with_message(message)
end

Then 'I see everything is committed' do
  expect(local_repository_pathname).not_to have_any_changes
end

Then(/^I see everything is committed except #{FILE_REGEX}$/) do |filename|
  expect(local_repository_pathname).not_to have_indexed(filename)
  expect(local_repository_pathname).not_to have_any_changes
end

Then 'I see everything is committed except:' do |table|
  table.raw.flatten.compact.each do |filename|
    expect(local_repository_pathname).not_to have_indexed(filename)
  end
  expect(local_repository_pathname).not_to have_any_changes
end

Then(/^I see #{FILE_REGEX} is removed and deleted$/) do |filename|
  expect(local_repository_pathname.join(filename)).not_to exist
end

################################################################################

def local_repository_pathname
  Pathname('tmp').join('features', 'repository')
end
