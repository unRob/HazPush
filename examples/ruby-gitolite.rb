# coding: utf-8
require 'rubygems'
require 'httparty'
require 'json'
require 'base64'
require 'parseconfig'
require 'openssl'
require 'cgi'
require 'pp'


=begin
Para gitolite, usamos los siguientes parámetros de configuración:

[repo miRepo]
  config deploy.url = urlPublicoDelApp.com
  config deploy.port = 3000
  config deploy.fullname = "Nombre friendly" //sin uso todavía
  config deploy.key = "Una llave rididicula, por ahora sin acentos"
  config deploy.server = jeltz //El nombre del usuario 'server', por si hacemos push desde el server.
  

Es importante que se habilite la configuración necesaria en gitolite.rc y se cargue haciendo de nuevo `gl-setup`!
=end

user = ENV['GL_USER'] || 'anonimo'
repo = ENV['GL_REPO']
base = ENV['GL_REPO_BASE_ABS']

config = ParseConfig.new("#{base}/#{repo}.git/config").params['deploy']

#No hay nada que hacer acá, sólo es un repo sin  
if (!config)
  puts "Gracias, #{user}"
  exit(true);
end


defaults = {
	url: 'localhost',
	port: false,
	fullname: repo,
	key: "Esta es una llave falsa",
	server: 'arthur'
}


config = defaults.merge(config)

if( user==config['server'] )
  puts "Hola server!"
  exit(true);
end


puts 'Hola '+user+'!'

argses = $stdin.readlines
argses = argses[0].split(' ')

oldrev = argses[0].dup
newrev = argses[1].dup
refname = argses[2].dup


if( argses.count != 3 )
  #Zoquete!
  puts argses.count
  puts argses
  puts "[ERROR] No recibí información del commit"
  exit(false)
end

puts ''

if( refname != "refs/heads/master" )
  #No estamos en master, no quiero dev ó feature-branches en el server
  puts "[WARN] No mandaré nada al server"
  exit(true)
end


#Ahora sí, comenzamos a hacer pull
puts '-'*70
STDOUT.write "- Actualizando repo... "
  
refs = {
  'de'      => oldrev,
  'a'       => newrev,
  'branch'  => refname
}

  
port = config['port'] ? ":#{config['port']}" : '';
scheme = config['https'] ? 'https' : 'http';
url = "#{scheme}://#{config['url']}#{port}"
  
headers = {
  'X-Auth' => OpenSSL::HMAC.hexdigest('sha256', config['key'], "GET::/pull")
}


r = HTTParty.get("#{url}/pull", :headers => headers)

if( r.success? )
  response = JSON.parse r.body
  if( !response['error'] )
    status = "SUCCESS"
    razon = "Deployment listo"
    puts "#{status}! #{razon} -\n"
    puts '-'*70
    STDOUT.write response['summary']
  end
else
  error = "error"
  razon = "Se cagó el server"
  STDOUT.write "#{error}! #{razon} -\n"
  puts '-'*70
  begin
    response = JSON.parse Base64.decode64(r)
    STDOUT.write "#{response['razon']}"
      
    pp response
  rescue
    puts r.code
  end
end
puts ''
