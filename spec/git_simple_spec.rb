require 'spec_helper'

RSpec.describe GitSimple do
  subject(:git_simple) { described_class.new(repository_pathname) }

  let(:current_directory)          { Pathname('tmp').join('spec') }
  let(:repository_pathname)        { current_directory.join('repository') }
  let(:remote_repository_pathname) { current_directory.join('remote_repository') }

  before { current_directory.rmtree if current_directory.directory? }

  describe 'initialization shortcut' do
    subject { GitSimple(:arg1, :arg2, :arg3) }

    before do
      allow(described_class).to receive(:new)
        .with(:arg1, :arg2, :arg3)
        .and_return(:result)
    end
    it { is_expected.to eq(:result) }
  end

  describe '#init' do
    subject { git_simple.init }

    it { is_expected.to eq(git_simple) }
    its_side_effects_are { expect(repository_pathname).to be_a_repository }
  end

  describe '#clone' do
    subject { git_simple.clone(pathname_or_remote_url) }

    before { GitFactory.create(remote_repository_pathname, :bare) }

    context 'with pathname' do
      let(:pathname_or_remote_url) { remote_repository_pathname.realpath }

      it { is_expected.to eq(git_simple) }
      its_side_effects_are { expect(repository_pathname).to exist }
    end

    context 'with URL string' do
      let(:pathname_or_remote_url) { "file://#{remote_repository_pathname.realpath}" }

      it { is_expected.to eq(git_simple) }
      its_side_effects_are { expect(repository_pathname).to exist }
    end
  end

  describe '#add' do
    subject { git_simple.add('file1', 'file2', 'dir1/dir2/file3', 'file4') }

    before do
      GitFactory.create(repository_pathname) do
        write('file1')
        write('file2')
        write('dir1', 'dir2', 'file3')
        write('file4')
        write('not_added')
      end
    end

    it { is_expected.to eq(git_simple) }

    its_side_effects_are do
      expect(repository_pathname).to have_indexed('file1')
      expect(repository_pathname).to have_indexed('file2')
      expect(repository_pathname).to have_indexed('dir1/dir2/file3')
      expect(repository_pathname).to have_indexed('file4')
      expect(repository_pathname).not_to have_indexed('not_added')
    end
  end

  describe '#add_all' do
    subject { git_simple.add_all }

    before do
      GitFactory.create(repository_pathname) do
        # Add a commit with a file that can be deleted.
        add('existing')
        commit('remote commit')
        delete('existing')
        # A file which is added to the index and then deleted.
        add('deleted')
        delete('deleted')
        # Then make a bunch of other changes.
        write('file1')
        write('file2')
        write('dir1', 'dir2', 'file3')
        write('file4')
      end
    end

    it { is_expected.to eq(git_simple) }

    its_side_effects_are do
      expect(repository_pathname).not_to have_indexed('deleted')
      expect(repository_pathname).to have_removed('existing')
      expect(repository_pathname).to have_indexed('file1')
      expect(repository_pathname).to have_indexed('file2')
      expect(repository_pathname).to have_indexed('dir1/dir2/file3')
      expect(repository_pathname).to have_indexed('file4')
    end
  end

  describe '#rm' do
    subject { git_simple.rm('file1', 'file2', 'dir1/dir2/file3', 'file4') }

    before do
      GitFactory.create(repository_pathname) do
        write('file1')
        write('file2')
        write('dir1', 'dir2', 'file3')
        write('file4')
        write('not_removed')
        commit_all('remote commit')
      end

      expect(described_class::Utils).to receive(:glob_to_pathnames) # rubocop:disable LineLength
        .and_call_original
    end

    it { is_expected.to eq(git_simple) }

    its_side_effects_are do
      expect(repository_pathname).to have_removed('file1')
      expect(repository_pathname).to have_removed('file2')
      expect(repository_pathname).to have_removed('dir1/dir2/file3')
      expect(repository_pathname).to have_removed('file4')
      expect(repository_pathname).not_to have_removed('not_removed')
    end
  end

  describe '#commit' do
    subject { timecopped(now) { git_simple.commit('new_commit', *args) } }

    let(:now) { Time.now }

    describe 'missing config' do # rubocop:disable RSpec/EmptyExampleGroup
      let(:args) { [] }

      before do
        GitFactory.create(repository_pathname)
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Rugged::Config).to receive(:[])
          .with('user.name')
          .and_return(user_name)
        allow_any_instance_of(Rugged::Config).to receive(:[])
          .with('user.email')
          .and_return(user_email)
        # rubocop:enable all
      end

      inputs           :user_name, :user_email
      raise_error_with nil,        nil,        GitSimple::Error
      raise_error_with nil,        nil,        'Cannot commit without a user name'
      raise_error_with :name,      nil,        GitSimple::Error
      raise_error_with :name,      nil,        'Cannot commit without a user email'
      raise_error_with nil,        :email,     GitSimple::Error
      raise_error_with nil,        :email,     'Cannot commit without a user name'
    end

    shared_examples_for 'executes' do
      context 'initial commit' do
        before do
          GitFactory.create(repository_pathname) do
            add('new_file')
          end
        end

        it { is_expected.to eq(git_simple) }

        its_side_effects_are do
          expect(repository_pathname).to have_commit(:head)
            .with_message('new_commit')
            .at(now)
            .by(expected_name, expected_email)
        end
      end

      context 'with existing commit' do
        let(:existing_commit_time) { now }

        before do
          Timecop.freeze(existing_commit_time) do
            GitFactory.create(repository_pathname) do
              add('existing')
              commit_all('existing')
              add('new_file')
            end
          end
        end

        it { is_expected.to eq(git_simple) }

        its_side_effects_are do
          expect(repository_pathname).to have_commit(:head)
            .with_message('new_commit')
            .at(now)
            .by(expected_name, expected_email)
          expect(repository_pathname).to have_commit(:head1)
            .with_message('existing')
            .at(existing_commit_time)
            .by(GitFactory.default_name, GitFactory.default_email)
        end
      end
    end

    context 'without options' do
      let(:args)           { [] }
      let(:expected_name)  { GitFactory.default_name }
      let(:expected_email) { GitFactory.default_email }

      it_behaves_like 'executes'
    end

    context 'with override options' do
      let(:args)           { [{ name: 'author', email: 'author@example.com' }] }
      let(:expected_name)  { 'author' }
      let(:expected_email) { 'author@example.com' }

      it_behaves_like 'executes'
    end
  end

  xdescribe '#pull' do
    subject { git_simple.pull }

    context 'with no remote' do
      it { is_expected.to eq(git_simple) }
    end

    context 'with no changes' do
      it { is_expected.to eq(git_simple) }
    end

    context 'with only remote changes' do
      it { is_expected.to eq(git_simple) }
    end

    context 'with non-conflicting changes' do
      it { is_expected.to eq(git_simple) }
    end

    context 'with conflicting changes' do
      it { is_expected.to eq(git_simple) }
    end
  end

  xdescribe '#push' do
    subject { git_simple.push }

    context 'with no remote' do
      it { is_expected.to eq(git_simple) }
    end

    xcontext 'with no changes' do
      it { is_expected.to eq(git_simple) }
    end

    xcontext 'with local changes' do
      it { is_expected.to eq(git_simple) }
    end

    xcontext 'with remote changes' do
      it { is_expected.to eq(git_simple) }
    end

    xcontext 'with remote and local changes' do
      it { is_expected.to eq(git_simple) }
    end
  end

  describe '#bypass' do
    subject do
      git_simple.bypass do |rugged, working_directory|
        tester.test(rugged, working_directory)
      end
    end

    let(:tester) { double }

    before do
      allow(Rugged::Repository).to receive(:discover)
        .with(repository_pathname.to_s)
        .and_return(rugged = instance_double(Rugged::Repository))
      allow(rugged).to receive(:workdir).and_return(:workdir)
      allow(Pathname).to receive(:new)
        .with(:workdir)
        .and_return(working_directory = instance_double(Pathname))

      expect(tester).to receive(:test).with(rugged, working_directory)
    end

    it { is_expected.to eq(git_simple) }
  end

  describe '#log' do
    subject { git_simple.log(*args).map(&:message) }

    context 'with no commits' do
      let(:args) { [] }

      before { GitFactory.create(repository_pathname) }
      it { is_expected.to eq([]) }
    end

    context 'with commits' do # rubocop:disable RSpec/EmptyExampleGroup
      before do
        GitFactory.create(repository_pathname) do
          # Add a commit with a file that can be deleted.
          add('dir/file1')
          commit('file1commit1')
          sleep(1)
          add('file2')
          commit('file2commit1')
          sleep(1)
          add('dir/file1', string: 'foobar')
          commit('file1commit2')
        end
      end

      inputs  :args
      it_with [],            %w[file1commit2 file2commit1 file1commit1]
      it_with %w[dir file1], %w[file1commit2 file1commit1]
      it_with %w[file2],     %w[file2commit1]
      it_with %w[nofile],    []
    end
  end

  describe '#remote_names' do
    subject { git_simple.remote_names }

    context 'with no remotes' do
      before { GitFactory.create(repository_pathname) }
      it { is_expected.to eq([]) }
    end

    context 'with remotes' do
      before do
        GitFactory.create(repository_pathname) do
          remote_create('remote1')
          remote_create('remote2')
        end
      end
      it { is_expected.to eq(%w[remote1 remote2]) }
    end
  end

  describe '#branch_names' do
    subject { git_simple.branch_names }

    context 'with no branches' do
      before { GitFactory.create(repository_pathname) }
      it { is_expected.to eq([]) }
    end

    context 'with master branch' do
      before do
        GitFactory.create(repository_pathname) do
          add('existing')
          commit('initial commit')
          branch_create('branch1')
        end
      end
      it { is_expected.to eq(%w[branch1 master]) }
    end
  end

  describe '#clean_working_tree?' do
    subject { git_simple.clean_working_tree? }

    context 'with no commits' do
      before { GitFactory.create(repository_pathname) }

      describe 'and no files' do
        it { is_expected.to eq(true) }
      end

      describe 'and any untracked files' do
        before do
          GitFactory.append(repository_pathname) { write('dir/newfile') }
        end
        it { is_expected.to eq(false) }
      end

      describe 'and any added files' do
        before do
          GitFactory.append(repository_pathname) { add('dir/newfile') }
        end
        it { is_expected.to eq(false) }
      end
    end

    context 'with commits' do
      before do
        GitFactory.create(repository_pathname) do
          add('.gitignore', string: "ignorefile\n")
          commit('add gitignore')
          add('dir/file1')
          commit('commit')
          write('ignorefile')
        end
      end

      describe 'and no changes' do
        it { is_expected.to eq(true) }
      end

      context 'and untracked file' do
        before do
          GitFactory.append(repository_pathname) { write('newfile') }
        end
        it { is_expected.to eq(false) }
      end

      context 'and changed committed file' do
        before do
          GitFactory.append(repository_pathname) { write('dir/file1', string: 'newstuff') }
        end
        it { is_expected.to eq(false) }
      end

      context 'and deleted committed file' do
        before do
          GitFactory.append(repository_pathname) { delete('dir/file1') }
        end
        it { is_expected.to eq(false) }
      end

      context 'and added to the index' do
        before do
          GitFactory.append(repository_pathname) { add('newfile') }
        end
        it { is_expected.to eq(false) }
      end

      context 'and removed from the index' do
        before do
          GitFactory.append(repository_pathname) { rm('dir/file1') }
        end
        it { is_expected.to eq(false) }
      end
    end
  end

  describe '#clean?' do
    it do
      # NOTE: Check for original_name because it is not supported in ruby2.0.0.
      # This can be removed once support for ruby2.0.0 is removed.
      skip unless git_simple.method(:clean?).respond_to?(:original_name)
      expect(git_simple.method(:clean?).original_name).to eq(:clean_working_tree?)
    end
  end
end
