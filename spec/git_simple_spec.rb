require 'spec_helper'

RSpec.describe GitSimple do
  subject(:git_simple) { described_class.new(repository_pathname) }

  let(:repository_pathname) { Pathname('tmp').join('spec', 'repository') }

  describe '#add' do
    subject { git_simple.add(*args) }

    before do
      GitFactory.init_f(repository_pathname) do
        write('file1')
        write('file2')
        write('dir1', 'dir2', 'file3')
        write('file4')
        write('not_added')
      end
    end

    shared_examples_for 'files are added to index' do
      it { is_expected.to eq(git_simple) }

      its_side_effects_are do
        expect(repository_pathname).to have_indexed('file1')
        expect(repository_pathname).to have_indexed('file2')
        expect(repository_pathname).to have_indexed('dir1/dir2/file3')
        expect(repository_pathname).to have_indexed('file4')
        expect(repository_pathname).not_to have_indexed('not_added')
      end
    end

    context 'filenames' do
      let(:args) { %w[file1 file2 dir1/dir2/file3 file4] }

      it_behaves_like 'files are added to index'
    end

    context 'filename arrays' do
      let(:args) { [%w[file1], %w[file2], %w[dir1 dir2 file3], %w[file4]] }

      it_behaves_like 'files are added to index'
    end

    context 'pathnames' do
      let(:args) { [Pathname('file1'), Pathname('file2'), Pathname('dir1/dir2/file3'), Pathname('file4')] } # rubocop:disable Metrics/LineLength

      it_behaves_like 'files are added to index'
    end

    context 'globed' do
      let(:args) { [Pathname('file*'), 'dir1/**/*'] }

      it_behaves_like 'files are added to index'
    end

    context 'directory' do
      let(:args) { %w[file1 file2 dir1 file4] }

      it_behaves_like 'files are added to index'
    end
  end

  describe '#add_all' do
    subject { git_simple.add_all }

    before do
      GitFactory.init_f(repository_pathname) do
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
    subject { git_simple.rm(*args) }

    before do
      GitFactory.init_f(repository_pathname) do
        write('file1')
        write('file2')
        write('dir1', 'dir2', 'file3')
        write('file4')
        write('not_removed')
        commit_all('remote commit')
      end
    end

    shared_examples_for 'files are removed from index' do
      it { is_expected.to eq(git_simple) }

      its_side_effects_are do
        expect(repository_pathname).to have_removed('file1')
        expect(repository_pathname).to have_removed('file2')
        expect(repository_pathname).to have_removed('dir1/dir2/file3')
        expect(repository_pathname).to have_removed('file4')
        expect(repository_pathname).not_to have_removed('not_removed')
      end
    end

    context 'filenames' do
      let(:args) { %w[file1 file2 dir1/dir2/file3 file4] }

      it_behaves_like 'files are removed from index'
    end

    context 'filename arrays' do
      let(:args) { [%w[file1], %w[file2], %w[dir1 dir2 file3], %w[file4]] }

      it_behaves_like 'files are removed from index'
    end

    context 'pathnames' do
      let(:args) { [Pathname('file1'), Pathname('file2'), Pathname('dir1/dir2/file3'), Pathname('file4')] } # rubocop:disable Metrics/LineLength

      it_behaves_like 'files are removed from index'
    end

    context 'globed' do
      let(:args) { [Pathname('file*'), 'dir1/**/*'] }

      it_behaves_like 'files are removed from index'
    end

    context 'directory' do
      let(:args) { %w[file1 file2 dir1 file4] }

      it_behaves_like 'files are removed from index'
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
        GitFactory.init_f(repository_pathname) do
          add('new_file')
        end
      end

      it { is_expected.to eq(git_simple) }

      its_side_effects_are do
        expect(repository_pathname).to have_commit(:head).with(
          'new_commit', now, name: 'author', email: 'author@example.com'
        )
      end
    end

    context 'with existing commit' do
      let(:existing_commit_time) { now }

      before do
        Timecop.freeze(existing_commit_time) do
          GitFactory.init_f(repository_pathname) do
            add('existing')
            commit_all('existing')
            add('new_file')
          end
        end
      end

      it { is_expected.to eq(git_simple) }

      its_side_effects_are do
        expect(repository_pathname).to have_commit(:head).with(
          'new_commit', now, name: 'author', email: 'author@example.com'
        )
        expect(repository_pathname).to have_commit(:head1).with(
          'existing', existing_commit_time,
          name: GitFactory.default_name, email: GitFactory.default_email
        )
      end
    end
  end
end
