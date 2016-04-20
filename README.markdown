# Hazpush

A nodejs app to `git pull` on a remote server.

## Installation

`npm install -g hazpush`

## Usage

### Configure your github credentials and server port/hostname
```
hazpush setup
```

### Now, go ahead and add the server repo to be watched
```
hazpush add /var/www/someWebApp
```

### Time to start the server and have it pull automagically
```
hazpush server start
```

## What happened to the post-pull hooks?

Well, those can be accomplished by [setting up a post-merge hook](https://gist.github.com/sindresorhus/7996717).

## Configuration

If you want to put HazPush behind a webserver like [Nginx](http://nginx.org/) or
[Apache HTTPD](http://httpd.apache.org/), you can specify the port the webserver
listens on independently of the port the HazPush server listens on with the
"listenPort" configuration option.
