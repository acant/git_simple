# rubocop:disable Security/Eval
# Using eval here to handle script execution and output checking. This seems
# safe while testing and will not be used in the production code.

FILE_REGEX = /'([^']+)'/

Given 'a local repository' do
  GitFactory.create(local_repository_pathname)
end

Given(/^a remote repository accessible by (\w+)$/) do |protocol|
  GitFactory.create(remote_repository_pathname, :bare)

  @protocol = protocol
  case protocol
  when 'file'  then nil # nothing to do
  when 'git'   then pending
  when 'http'  then pending
  when 'https' then pending
  when 'ssh'   then pending
  else
    pending
  end
end

Given 'a local clone' do
  GitFactory.clone(local_repository_pathname, remote_repository_pathname)
end

Given(/^#{FILE_REGEX} is committed( in the remote repository)?(?: with #{FILE_REGEX})?$/) do |filename, remote_flag, content| # rubocop:disable Metrics/LineLength
  repository_pathname =
    if remote_flag
      remote_repository_pathname
    else
      local_repository_pathname
    end
  GitFactory.append(repository_pathname) do
    add(filename, string: content)
    commit("filename #{filename} commit")
  end
end

Given(/^has uncommitted files:$/) do |table|
  GitFactory.append(local_repository_pathname) do
    table.raw.each { |row| write(row.first) }
  end
end

Given(/^a (remote|branch) called #{FILE_REGEX}$/) do |type, name|
  GitFactory.append(local_repository_pathname) do
    case type
    when 'remote' then remote_create(name)
    when 'branch' then branch_create(name)
    end
  end
end

When(/^the #{FILE_REGEX} file is deleted$/) do |filename|
  GitFactory.append(local_repository_pathname) do
    delete(filename)
  end
end

When 'I execute:' do |script|
  protocol_url =
    case @protocol
    when 'file' then "'file://#{remote_repository_pathname.realpath}'"
    else
      'nothing'
    end
  updated_script = script.gsub('<protocol_url>', protocol_url)
  @script_result = nil
  expect { @script_result = instance_eval(updated_script) }.not_to raise_error
end

Then 'I see a local repository' do
  expect(local_repository_pathname).to be_a_repository
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

Then(/^I see #{FILE_REGEX} contains #{FILE_REGEX}$/) do |filename, content|
  expect(local_repository_pathname.join(filename)).to exist
  expect(local_repository_pathname.join(filename).read).to eq(content)
end

Then 'I see the repositories are synchronized' do
  expect(local_repository_pathname).to be_synchronized_with(remote_repository_pathname)
end

Then 'I see the output:' do |expected_result_string|
  expect(@script_result).to eq(eval(expected_result_string))
end

Then(/^I see the output: (.+)$/) do |expected_result_string|
  expect(@script_result).to eq(eval(expected_result_string))
end

Then 'I see the output includes:' do |expected_result_string|
  expected_result = eval(expected_result_string)

  expect(@script_result.size).to eq(expected_result.size)
  expected_result.each_with_index do |value, index|
    expect(@script_result[index]).to include(value)
  end
end

################################################################################

def local_repository_pathname
  Pathname('tmp').join('features', 'local_repository')
end

def remote_repository_pathname
  Pathname('tmp').join('features', 'remote_repository')
end
