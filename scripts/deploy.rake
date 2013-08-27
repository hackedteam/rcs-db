class DeployMachine
  attr_reader :user, :address, :local_root

  def initialize(params)
    @user = params[:user]
    @address = params[:address]
  end

  def add_slash(path)
    path.end_with?('/') ? "#{path}" : "#{path}/"
  end

  def mirror(local_folder, remote_folder, opts = {})
    src = add_slash(local_folder)
    dst = add_slash(remote_folder)
    system("rsync --delete -vaz \"#{src}\" #{user}@#{address}:\"#{dst}\"", opts)
  end

  def restart_service(name)
    send_command("net stop \"#{name}\"; net start \"#{name}\"")
  end

  def send_command(command, opts = {})
    system("ssh #{user}@#{address} \""+ command.gsub('"', '\"') +"\"", opts)
  end

  def system(cmd, opts = {})
    puts "executing: #{cmd}"
    opts[:trap] ? `#{cmd}` : Kernel.system(cmd)
  end
end


namespace :castore do

  def machine
    @machine ||= DeployMachine.new(user: 'Administrator', address: '192.168.100.100')
  end

  def root
    @root ||= File.expand_path File.join(File.dirname(__FILE__), '..')
  end

  namespace :sc do

    desc "Show the status of all the rcs-related services"
    task :status do |args|
      result = machine.send_command('sc query type= service state= all', trap: true)
      result.split("SERVICE_NAME:")[1..-1].each do |text|
        name = text.lines.first.strip
        next if name !~ /RCS/i and name !~ /mongo/i
        next if name =~ /RCSDB\-/
        state = text.lines.find{ |l| l =~ /STATE/ }.split(':').last.gsub(/\d/, '').strip
        state.downcase! if state == 'RUNNING'
        puts "#{name.ljust(20)} #{state}"
      end
    end

    desc "Restart a Windows service"
    task :restart, [:service_name] do |task, args|
      machine.restart_service(args.service_name)
    end
  end

  desc 'Deploy all the code in the lib folder'
  task :deploy do
    if machine.system("cd \"#{root}\" && git status", trap: true) !~ /nothing to commit, working directory clean/
      print 'You have pending changes, continue (y/n)? '
      exit if STDIN.getc != 'y'
    end

    Rake::Task['castore:backup'].invoke

    services_to_restart = []
    %w[Aggregator Intelligence OCR Translate Worker DB].each do |service|
      name = service.downcase
      result = machine.mirror("#{root}/lib/rcs-#{name}/", "rcs/DB/lib/rcs-#{name}-release/", trap: true)
      something_changed = result.split("\n")[1..-3].reject { |x| x.empty? }.any?

      if something_changed
        services_to_restart << "RCS#{service}"
        puts result
      else
        puts 'nothing changed'
      end
    end

    services_to_restart.each do |service|
      machine.restart_service(service)
    end
  end

  namespace :deploy do

    desc 'Rollback the last deploy (if any)'
    task :rollback do
      result = machine.send_command("ls deploy_backups/", trap: true)
      folder = result.split(" ").sort.last

      if folder
        machine.send_command("cp -r deploy_backups/#{folder}/lib/* rcs/DB/lib")
      else
        puts "No backups found :("
      end
    end
  end

  task :backup do
    folder = "#{Time.now.to_i}"
    machine.send_command("mkdir deploy_backups/#{folder}; cp -r rcs/DB/lib deploy_backups/#{folder}")
  end
end
