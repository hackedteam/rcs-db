def shared_spec_for(core, params = {})
  enable_license

  def local_cores_path
    File.expand_path('../../../../../cores', __FILE__)
  end

  def certs_path
    File.expand_path('../../../../../config/certs', __FILE__)
  end

  def remote_cores_path
    "/Volumes/SHARE/RELEASE/SVILUPPO/cores galileo"
  end

  let(:melt_file) do
    params[:melt]
  end

  before(:all) do
    do_not_empty_test_db

    @signature = ::Signature.create!(scope: 'agent', value: 'A'*32)

    @operation = factory_create(:operation)

    @target = factory_create(:target, operation: @operation)

    ident = "RCS_#{rand(1E6)}test"

    @factory = Item.create!(name: 'testfactory', _kind: :factory, path: [@operation.id, @target.id], stat: ::Stat.new, good: true).tap do |f|
      f.update_attributes(logkey: 'L'*32, confkey: 'C'*32, ident: ident, seed: '88888888.333')
      f.configs << Configuration.new(config: 'test_config')
    end

    @agent = factory_create(:agent, target: @target, version: 2013031102, platform: core.to_s, ident: ident)

    FileUtils.cp(fixtures_path(params[:melt]), RCS::DB::Config.instance.temp) if params[:melt]
    FileUtils.cp("#{remote_cores_path}/#{core}.zip", "#{local_cores_path}/")
  end

  before(:each) do
    subject.stub(:archive_mode?).and_return false
    RCS::DB::Build.any_instance.stub(:license_magic).and_return 'WmarkerW'

    core_loaded = Mongoid.default_session['cores'].find(name: core).first
    RCS::DB::Core.load_core ("./cores/#{core}.zip") unless core_loaded
  end
end
