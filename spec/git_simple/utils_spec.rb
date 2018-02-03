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

  describe '.glob_to_pathnames' do
    subject do
      described_class.glob_to_pathnames(
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

    it { is_expected.to eq([file1, file2, file4, file3, other]) }

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
end
