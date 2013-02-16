desc 'build a gem release and push it to dev'
task :release do
  $: << './lib'
  require 'wirer/version'
  sh 'gem build wirer.gemspec'
  sh "scp wirer-#{Wirer::VERSION}.gem dev.playlouder.com:/var/www/gems.playlouder.com/pending"
  sh "ssh dev.playlouder.com sudo include_gems.sh /var/www/gems.playlouder.com/pending"
end

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
  t.options = '--verbose'
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/**/*_test.rb']
    t.verbose = true
  end
rescue LoadError
end

begin
  require 'yard'
  OTHER_PATHS = ['README.md', 'README.rb']
  YARD::Rake::YardocTask.new do |t|
    t.files   = ['lib/**/*.rb', '-'] + OTHER_PATHS
    t.options = ['--private']
  end
rescue NameError
  $stderr.puts('yard not installed, no yard task defined')
end

load 'lib/wirer/version.rb'
desc 'deploy the docs to public.playlouder.com'
task :deploy_docs => :yard do
  fname = "wirer-#{Wirer::VERSION}-doc.tar.gz"
  host = 'public.playlouder.com'
  www_dir = "/var/www/public.playlouder.com/doc/wirer/"
  `tar -czf #{fname} doc`
  `scp #{fname} #{host}:/tmp/.`
  `ssh #{host} tar xf /tmp/#{fname} --strip-components=1 -C #{www_dir}`
end
