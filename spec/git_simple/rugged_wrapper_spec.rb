require 'spec_helper'

RSpec.describe GitSimple::RuggedWrapper do
  subject(:rugged_wrapper) { described_class.new(repository_pathname) }

  let(:current_directory)   { Pathname('tmp').join('spec') }
  let(:repository_pathname) { current_directory.join('repository') }
  let(:repository)          { Rugged::Repository.new(repository_pathname.to_s) }
  let(:head_commit)         { repository.head }

  before { current_directory.rmtree if current_directory.directory? }

  describe '#rugged' do
    subject { rugged_wrapper.rugged }

    before { GitFactory.create(repository_pathname) }
    it { is_expected.to be_kind_of(Rugged::Repository) }
  end

  describe '#working_directory' do
    subject { rugged_wrapper.working_directory }

    before { GitFactory.create(repository_pathname) }
    it { is_expected.to eq(repository_pathname.realpath ) }
  end

  describe '#head_target' do
    subject { rugged_wrapper.head_target }

    context 'with no commits' do
      before { GitFactory.create(repository_pathname) }
      it { is_expected.to eq(nil) }
    end

    context 'with commits' do
      before do
        GitFactory.create(repository_pathname) do
          add('filename')
          commit('commit')
        end
      end
      it { is_expected.to eq(head_commit.target) }
    end
  end

  describe '#head_ref' do
    subject { rugged_wrapper.head_ref }

    context 'with no commits' do
      before { GitFactory.create(repository_pathname) }
      it { is_expected.to eq(nil) }
    end

    context 'with commits' do
      before do
        GitFactory.create(repository_pathname) do
          add('filename')
          commit('commit')
        end
      end
      it { is_expected.to eq('refs/heads/master') }
    end
  end

  describe '#head_branch' do
    subject { rugged_wrapper.head_branch }

    context 'with no commits' do
      before { GitFactory.create(repository_pathname) }
      it { is_expected.to eq(repository.branches['master']) }
    end

    context 'with commits' do
      before do
        GitFactory.create(repository_pathname) do
          add('filename')
          commit('commit')
        end
      end
      it { is_expected.to eq(repository.branches['master']) }
    end
  end

  describe '#head_remote' do
    subject { rugged_wrapper.head_remote }

    shared_examples_for 'has' do
      describe 'no remote' do
        before { GitFactory.append(repository_pathname) }
        it { is_expected.to eq(nil) }
      end

      describe 'only origin' do
        before do
          GitFactory.append(repository_pathname) do
            remote_create('origin')
          end
        end
        its(:url) { is_expected.to eq(repository.remotes['origin'].url) }
      end
    end

    context 'with no commits' do
      before { GitFactory.create(repository_pathname) }
      it_behaves_like 'has'
    end

    context 'with commits' do
      before do
        GitFactory.create(repository_pathname) do
          add('filename')
          commit('commit')
        end
      end
      it_behaves_like 'has'
    end

    context 'with commits and tracking branch' do
      before do
        remote_repository_pathname = current_directory.join('remote_repository')
        GitFactory.create(remote_repository_pathname, :bare)
        GitFactory.clone(remote_repository_pathname, repository_pathname) do
          add('filename')
          commit('commit')
          remote_create(
            'upstream', "file://#{remote_repository_pathname.realpath}"
          ).fetch
          rugged.branches['master'].upstream = rugged.branches['upstream/master']
        end
      end
      its(:url) { is_expected.to eq(repository.remotes['upstream'].url) }
    end

  end

  describe '#head_remote_branch' do
    subject { rugged_wrapper.head_remote_branch }

    context 'with no commits' do
      before { GitFactory.create(repository_pathname) }
      it { is_expected.to eq(nil) }
    end

    context 'with no remote' do
      before do
        GitFactory.create(repository_pathname) do
          add('filename')
          commit('commit')
        end
      end
      it { is_expected.to eq(nil) }
    end

    context 'with no remote branch' do
      before do
        GitFactory.create(repository_pathname) do
          add('filename')
          commit('commit')
          remote_create('origin')
        end
      end

      it { is_expected.to eq(nil) }
    end

    context 'with no upstream' do
      before do
        GitFactory.create(repository_pathname) do
          add('filename')
          commit('commit')
          remote_create('origin')
          branch_create('origin/master')
        end
      end
      it { is_expected.to eq(repository.branches['origin/master']) }
    end

    context 'with upstream' do
    end
  end

  xdescribe '#commit_create' do
  end

  xdescribe '#index_write' do
  end

  xdescribe '#glob_to_index' do
  end
end
