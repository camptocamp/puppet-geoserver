# See README.md for more documentation.
class geoserver(
  $server_name         = 'geoserver',
  $server_port         = 8005,
  $connector_port      = 8080,
  $address             = $::fqdn,
  $data_dir            = undef,
  $cache_dir           = undef,
  $java_opts           = undef,
  $java_xms            = '2G',
  $java_xmx            = '2G',
  $java_xx_maxpermsize = '256m',
  $java_xx_permsize    = '256m',
  $ssl                 = false,
  $truststorefile      = undef,
  $truststorepass      = undef,
) {
  $jai_pkg = $::osfamily ? {
    'Debian' => 'libjai-imageio-core-java',
    'RedHat' => 'jai-imageio-core',
  }

  package { 'libjai-imageio-core-java':
    ensure => present,
    name   => $jai_pkg,
  }

  $common_java_opts = '-Dfile.encoding=UTF8 -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -server -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:ParallelGCThreads=2 -XX:SoftRefLRUPolicyMSPerMB=36000 -XX:NewRatio=2 -XX:+AggressiveOpts'

  $ssl_java_opts = $ssl ? {
    true  => " -Djavax.net.ssl.trustStore=${truststorefile} -Djavax.net.ssl.trustStorePassword=${truststorepass}",
    false => '',
  }

  $common_env = [
    'USE_IMAGEMAGICK="true"',
    "ADD_JAVA_OPTS=\"${common_java_opts}${ssl_java_opts}\"",
    "JAVA_XMS=\"${java_xms}\"",
    "JAVA_XMX=\"${java_xmx}\"",
    "JAVA_XX_PERMSIZE=\"${java_xx_permsize}\"",
    "JAVA_XX_MAXPERMSIZE=\"${java_xx_maxpermsize}\"",
  ]

  $data_dir_env = $data_dir ? {
    undef   => [],
    default => [ "GEOSERVER_DATA_DIR=\"${data_dir}\"", ],
  }

  $cache_dir_env = $cache_dir ? {
    undef   => [],
    default => [ "GEOWEBCACHE_CACHE_DIR=\"${cache_dir}\"", ],
  }

  $connector_scheme = $ssl ? {
    true  => 'https',
    false => 'http',
  }

  include ::tomcat

  tomcat::instance { 'geoserver':
    ensure             => present,
    default_connectors => false,
    manage             => true,
    server_port        => $server_port,
    setenv             => concat( $common_env, $data_dir_env, $cache_dir_env ),
    java_opts          => $java_opts,
  }

  tomcat::connector { "${connector_scheme}-${connector_port}-${name}":
    ensure   => present,
    instance => 'geoserver',
    manage   => true,
    options  => [ 'minSpareThreads="20"' ],
    port     => $connector_port,
    protocol => 'HTTP/1.1',
    scheme   => $connector_scheme,
  }

  if $ssl {
    exec { 'Create truststore dir':
      command => "/bin/mkdir -p `dirname ${truststorefile}`",
      unless  => "/usr/bin/test -d `dirname ${truststorefile}`",
    }
    -> exec { 'Import default truststore':
      command => "/usr/bin/keytool -importkeystore -srckeystore /etc/ssl/certs/java/cacerts -destkeystore ${truststorefile} -srcstorepass changeit -deststorepass ${truststorepass}",
      creates => $truststorefile,
      require => Class['java'],
    }
    -> java_ks { 'geoserver:truststore':
      ensure       => present,
      certificate  => '/var/lib/puppet/ssl/certs/ca.pem',
      target       => $truststorefile,
      password     => $truststorepass,
      trustcacerts => true,
    }
  }

  if $data_dir {
    exec { "Create ${name} GEOSERVER_DATA_DIR":
      command => "/bin/mkdir -p `dirname ${data_dir}`",
      unless  => "/usr/bin/test -d `dirname ${data_dir}`",
    }
    -> file { $data_dir:
      ensure => directory,
      owner  => 'tomcat',
      group  => 'tomcat',
      mode   => '0755',
    }
  }

  if $::osfamily == 'Debian' and versioncmp($::operatingsystemmajrelease, '7') >= 0 {
    package { 'libgdal-java':
      ensure => present,
    }
  }

  if $cache_dir {
    exec { "/bin/mkdir -p `dirname ${cache_dir}`":
      unless => "/usr/bin/test -d `dirname ${cache_dir}`",
      before => File[$cache_dir],
    }
    file { $cache_dir:
      ensure => directory,
      owner  => 'tomcat',
      group  => 'tomcat',
      mode   => '0755',
    }
  }
}
