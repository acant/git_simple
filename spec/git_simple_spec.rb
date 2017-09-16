require 'spec_helper'

RSpec.describe GitSimple do
  subject(:git_simple) { described_class.new(repository_pathname) }

  let(:repository_pathname) { Pathname('tmp').join('spec', 'repository') }

  describe 'initialization shortcut' do
    subject { GitSimple(:arg1, :arg2, :arg3) }

    before do
      allow(described_class).to receive(:new)
        .with(:arg1, :arg2, :arg3)
        .and_return(:result)
    end
    it { is_expected.to eq(:result) }
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
      expect(described_class::Utils).to receive(:glob_to_pathnames) # rubocop:disable RSpec/MessageSpies, LineLength
        .and_call_original
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

      expect(described_class::Utils).to receive(:glob_to_pathnames) # rubocop:disable RSpec/MessageSpies, LineLength
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
    subject do
      timecopped(now) do
        git_simple.commit('new_commit', name: 'author', email: 'author@example.com')
      end
    end

    let(:now) { Time.now }

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
          .by('author', 'author@example.com')
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
          .by('author', 'author@example.com')
        expect(repository_pathname).to have_commit(:head1)
          .with_message('existing')
          .at(existing_commit_time)
          .by(GitFactory.default_name, GitFactory.default_email)
      end
    end
  end
end
