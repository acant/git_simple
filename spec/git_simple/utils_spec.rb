require 'spec_helper'

# rubocop:disable SpaceBeforeSemicolon, Semicolon
# rubocop:disable RSpec/EmptyLineAfterFinalLet

RSpec.describe GitSimple::Utils do
  describe '.to_pathname' do
    subject { described_class.to_pathname(*args) }

    let(:filename) { File.join(%w[path1 path2 path3 path4]) }
    let(:pathname) { Pathname(filename) }

    context { let(:args) { [pathname] }                                    ; it { is_expected.to eq(pathname) } }
    context { let(:args) { [[pathname]] }                                  ; it { is_expected.to eq(pathname) } }
    context { let(:args) { [filename] }                                    ; it { is_expected.to eq(pathname) } }
    context { let(:args) { [[filename]] }                                  ; it { is_expected.to eq(pathname) } }
    context { let(:args) { [%w[path1 path2], File.join(%w[path3 path4])] } ; it { is_expected.to eq(pathname) } }
    context { let(:args) { %w[path1 path2 path3 path4] }                   ; it { is_expected.to eq(pathname) } }
    context { let(:args) { ['path1', nil, %w[path2 path3], nil, 'path4'] } ; it { is_expected.to eq(pathname) } }
  end

  describe '.each_with_glob' do # rubocop:disable RSpec/EmptyExampleGroup
    subject do
      described_class.each_with_glob(
        [Pathname('file*'), 'dir1', 'other'],
        base_pathname
      ) { |relative_path, realpath| object.test(relative_path, realpath) }
    end

    let(:object)        { spy }
    let(:base_pathname) { Pathname('tmp').join('spec', 'utils') }
    let(:file1)         { base_pathname.join('file1') }
    let(:file2)         { base_pathname.join('file2') }
    let(:file3)         { base_pathname.join('dir1', 'dir2', 'file3') }
    let(:file4)         { base_pathname.join('file4') }
    let(:other)         { base_pathname.join('other') }

    before do
      FileTreeFactory.create(base_pathname) do
        write('file1')
        write('file2')
        write('dir1', 'dir2', 'file3')
        write('file4')
        write('other')
      end
    end

    its_side_effects_are do
      expect(object).to have_received(:test)
        .with(Pathname('file1'), file1.realpath)
      expect(object).to have_received(:test)
        .with(Pathname('file2'), file2.realpath)
      expect(object).to have_received(:test)
        .with(Pathname(File.join('dir1', 'dir2', 'file3')), file3.realpath)
      expect(object).to have_received(:test)
        .with(Pathname('file4'), file4.realpath)
      expect(object).to have_received(:test)
        .with(Pathname('other'), other.realpath)
    end
  end

  describe 'git_clone_url' do
    subject { described_class.git_clone_url(remote_or_url) }

    before do
      allow(GitCloneUrl).to receive(:parse)
        .with(:remote_url)
        .and_return(:result)
    end

    context 'with remote' do
      let(:remote_or_url) { instance_double(Rugged::Remote, url: :remote_url) }

      it { is_expected.to eq(:result) }
    end

    context 'with URL string' do
      let(:remote_or_url) { :remote_url }

      it { is_expected.to eq(:result) }
    end
  end

  describe '.build_remote_options' do # rubocop:disable RSpec/EmptyExampleGroup
    subject { described_class.build_remote_options(:remote_or_url, options) }

    before do
      allow(Etc).to receive(:getlogin).and_return('user')
      allow(described_class).to receive(:git_clone_url)
        .and_return(GitCloneUrl.parse(remote_url))
      allow(Rugged::Credentials::UserPassword).to receive(:new)
        .with(username: 'user', password: :password)
        .and_return(:rugged_credentials_user_password)
      allow(Rugged::Credentials::SshKey).to receive(:new).with(
        username:   'user',
        publickey:  Pathname(ENV['HOME']).join('.ssh/id_rsa.pub').to_s,
        privatekey: Pathname(ENV['HOME']).join('.ssh/id_rsa').to_s,
        passphrase: :ssh_passphrase
      ).and_return(:rugged_credentials_ssh_key)
    end

    # rubocop:disable Style/BracesAroundHashParameters
    inputs  :remote_url,                            :options
    it_with 'file:///path/to/repo.git/',            {},                                                {}
    it_with 'ssh://host.xz/path/to/repo.git/',      { ssh_passphrase: :ssh_passphrase },               { credentials: :rugged_credentials_ssh_key }
    it_with 'ssh://user@host.xz/path/to/repo.git/', { ssh_passphrase: :ssh_passphrase },               { credentials: :rugged_credentials_ssh_key }
    it_with 'ssh://host.xz/path/to/repo.git/',      { user: 'user', ssh_passphrase: :ssh_passphrase }, { credentials: :rugged_credentials_ssh_key }
    it_with 'host.xz:path/to/repo.git/',            { ssh_passphrase: :ssh_passphrase },               { credentials: :rugged_credentials_ssh_key }
    it_with 'user@host.xz:path/to/repo.git/',       { ssh_passphrase: :ssh_passphrase },               { credentials: :rugged_credentials_ssh_key }
    it_with 'host.xz:path/to/repo.git/',            { user: 'user', ssh_passphrase: :ssh_passphrase }, { credentials: :rugged_credentials_ssh_key }
    it_with 'http://host.xz/path/to/repo.git/',     {},                                                {}
    it_with 'http://host.xz/path/to/repo.git/',     { user: 'user', password: :password },             { credentials: :rugged_credentials_user_password }
    it_with 'https://host.xz/path/to/repo.git/',    {},                                                {}
    it_with 'https://host.xz/path/to/repo.git/',    { user: 'user', password: :password },             { credentials: :rugged_credentials_user_password }
    # rubocop:enable Style/BracesAroundHashParameters

    # TODO: These Git URLs are not currently supported by GitCloneUrl. In the
    # future support can either be added into GitCloneUrl, or added here.
    # it_with '/path/to/repo.git/',                     {}, {}
    # it_with 'git://host.xz[:port]/path/to/repo.git/', {}, {}
  end

  describe '.split_options' do # rubocop:disable RSpec/EmptyExampleGroup
    subject { described_class.split_options(*args) }

    inputs  :args
    it_with [],                              [[],            {}]
    it_with %i[arg1 arg2],                   [%i[arg1 arg2], {}]
    it_with [{ key: :value }],               [[],            { key: :value }]
    it_with [:arg1, :arg2, { key: :value }], [%i[arg1 arg2], { key: :value }]
  end

  describe '.process_clone_args' do
    subject do
      described_class.process_clone_args(pathname_or_remote_url, :arg1, :arg2, :arg3)
    end

    let(:options) { { directory: :directory } }
    before do
      allow(described_class).to receive(:split_options)
        .with(%i[arg1 arg2 arg3])
        .and_return([local_pathname_parts, options])
    end

    context 'with local_pathname' do
      let(:pathname_or_remote_url) { :noop }
      let(:local_pathname_parts)   { %i[part] }

      before do
        allow(described_class).to receive(:to_pathname)
          .with(:directory, local_pathname_parts)
          .and_return(:local_pathname)
      end
      it { is_expected.to eq([:local_pathname, options]) }
    end

    context 'with pathname and no local_pathname' do
      let(:pathname_or_remote_url) { Pathname('dir/basename.git') }
      let(:local_pathname_parts)   { [] }

      before do
        allow(described_class).to receive(:to_pathname)
          .with(:directory, Pathname('basename'))
          .and_return(:local_pathname)
      end
      it { is_expected.to eq([:local_pathname, options]) }
    end

    context 'with remote_url and no local_pathname' do
      let(:pathname_or_remote_url) { :remote_url }
      let(:local_pathname_parts)   { [] }

      before do
        allow(described_class).to receive(:git_clone_url)
          .with(:remote_url)
          .and_return(double(path: 'dir/url_basename.git'))
        allow(described_class).to receive(:to_pathname)
          .with(:directory, 'url_basename')
          .and_return(:local_pathname)
      end

      it { is_expected.to eq([:local_pathname, options]) }
    end
  end
end
