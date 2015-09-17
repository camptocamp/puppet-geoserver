require 'beaker-rspec'

hosts.each do |host|
  if host['platform'] =~ /^debian-/
    # Required for ttf-mscorefonts-installer
    on host, 'echo -e "deb http://httpredir.debian.org/debian jessie contrib" > /etc/apt/sources.list.d/debian-contrib.list'
    if host['platform'] =~ /^debian-8/
      # Required for libjai-imageio-* packages
      on host, 'echo -e "deb http://httpredir.debian.org/debian jessie non-free" > /etc/apt/sources.list.d/debian-non-free.list'
    end
  end

  if ENV['PUPPET_AIO']
    install_puppet_agent_on host, {}
  else
    install_puppet_on host
  end

  # Generate certificates for keystore
  on host, "puppet cert generate $(facter fqdn)"
end

RSpec.configure do |c|
  # Project root
  module_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  module_name = module_root.split('-').last

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module and dependencies
    puppet_module_install(:source => module_root, :module_name => module_name)

    hosts.each do |host|
      on host, puppet('module','install','herculesteam-augeasproviders_core'), { :acceptable_exit_codes => [0,1] }
      on host, puppet('module','install','herculesteam-augeasproviders_shellvar'), { :acceptable_exit_codes => [0,1] }
      on host, puppet('module','install','puppetlabs-java'), { :acceptable_exit_codes => [0,1] }
      on host, puppet('module','install','puppetlabs-java_ks'), { :acceptable_exit_codes => [0,1] }
      on host, puppet('module','install','puppetlabs-stdlib'), { :acceptable_exit_codes => [0,1] }
      on host, puppet('module','install','camptocamp-tomcat'), { :acceptable_exit_codes => [0,1] }
    end
  end
end
