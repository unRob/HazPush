# Hazpush

A nodejs app to `git pull` on a remote server.

## Installation

`npm install hazpush`

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