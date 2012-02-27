#Haz Push

Un app en Node.js para hacer deployment automático al hacer push.
Ya me cagó ruby en Ubuntu, necesitaba un proyectito para usar coffeescript


#Install
`npm install -g https://github.com/unRob/HazPush/tarball/master`


#Usage
$`hazpush /path/to/configFile.js`


#Configuración
Debe de ser un archivo JSON válido, like so:

    {
		"git_dir": "/path/to/repo" //este no debe de ser el .git, sino el dir que lo contiene,
		"key": "la llave que queremos usar para validar requests" //por el momento, sin acentos!
	}