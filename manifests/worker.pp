# See README.md for more documentation.
define geoserver::worker(
  $data_dir            = "/srv/tomcat/${name}/work/gs_data",
  $java_xmx            = '2G',
  $java_xx_permsize    = '256m',
  $java_xx_maxpermsize = '256m',
) {
  $worker_id      = regsubst(
    $name,
    "^${::geoserver::server_name}(\\d+)$",
    '\1')

  validate_re($worker_id, '^[0-9]+$')

  $server_port    = $::geoserver::server_port + $worker_id
  $connector_port = $::geoserver::connector_port + $worker_id

  $common_env = [
    'USE_IMAGEMAGICK="true"',
    "ADD_JAVA_OPTS=\"-Dfile.encoding=UTF8 -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -server -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:ParallelGCThreads=2 -XX:SoftRefLRUPolicyMSPerMB=36000 -XX:NewRatio=2 -XX:+AggressiveOpts -Djavax.net.ssl.trustStore=${::geoserver::truststorefile} -Djavax.net.ssl.trustStorePassword=${::geoserver::truststorepass}\"",
    "GEOSERVER_DATA_DIR=${data_dir}",
    "JAVA_XMS=\"${java_xmx}\"",
    "JAVA_XMX=\"${java_xmx}\"",
    "JAVA_XX_PERMSIZE=\"${java_xx_permsize}\"",
    "JAVA_XX_MAXPERMSIZE=\"${java_xx_maxpermsize}\"",
  ]

  $gwc_env = $::geoserver::embedded_geowebcache ? {
    true  => [ "GEOWEBCACHE_CACHE_DIR=\"${::geoserver::cache_dir}\"", ],
    false => [],
  }

  $connector_scheme = $::geoserver::ssl_only ? {
      true  => 'https',
      false => 'http',
  }

  include ::java
  include ::tomcat

  ensure_resource(
    'tomcat::instance',
    $name,
    {
      ensure             => present,
      default_connectors => false,
      manage             => true,
      server_port        => $server_port,
      setenv             => concat( $common_env, $gwc_env ),
    }
  )

  ensure_resource(
    'tomcat::connector',
    "http-${connector_port}-${name}",
    {
      ensure   => present,
      instance => $name,
      manage   => true,
      options  => [ 'minSpareThreads="20"' ],
      port     => $connector_port,
      protocol => 'HTTP/1.1',
      scheme   => $connector_scheme,
    }
  )

  ensure_resource(
    'exec',
    'Create truststore dir',
    {
      command => "/bin/mkdir -p `dirname ${::geoserver::truststorefile}`",
      creates => join(
        delete_at(split($::geoserver::truststorefile, '/'),
        size(split($::geoserver::truststorefile, '/')) - 1), '/'),
    }
  )

  ensure_resource(
    'exec',
    'Import default truststore',
    {
      command => "/usr/bin/keytool -importkeystore -srckeystore /etc/ssl/certs/java/cacerts -destkeystore ${::geoserver::truststorefile} -srcstorepass changeit -deststorepass ${::geoserver::truststorepass}",
      creates => $::geoserver::truststorefile,
      require => [
        Exec['Create truststore dir'],
        Class['java'],
      ],
    }
  )

  ensure_resource(
    'java_ks',
    'geoserver:truststore',
    {
      ensure       => present,
      certificate  => '/var/lib/puppet/ssl/certs/ca.pem',
      target       => $::geoserver::truststorefile,
      password     => $::geoserver::truststorepass,
      trustcacerts => true,
      require      => Exec['Import default truststore'],
    }
  )

  exec { "Create ${name} GEOSERVER_DATA_DIR":
    command => "/bin/mkdir -p `dirname ${data_dir}`",
    unless  => "/usr/bin/test -d `dirname ${data_dir}`",
    before  => File[$data_dir],
  }

  ensure_resource(
    'file',
    $data_dir,
    {
      ensure => directory,
      owner  => 'tomcat',
      group  => 'tomcat',
      mode   => '0755',
    }
  )

  if $::osfamily == 'Debian' and versioncmp($::operatingsystemmajrelease, '7') >= 0 {
    ensure_packages( [ 'libgdal-java', ] )
  }
  ensure_packages( [ 'ttf-mscorefonts-installer', ])

}
