module.exports = (grunt) ->
  grunt.initConfig
    coffee:
      compile:
        files:
          'js/main.js': 'src/*.coffee'
        options:
          join: true

    watch:
      scripts:
        files: ['src/*.coffee']
        tasks: ['coffee']

  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-watch')
