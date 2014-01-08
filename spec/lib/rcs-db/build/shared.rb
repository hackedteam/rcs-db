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
