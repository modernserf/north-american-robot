module.exports = (grunt)->

  grunt.initConfig {
    pkg: grunt.file.readJSON('package.json')

    coffee:
      build:
        files:
          "build/js/app.js" : "src/js/app.coffee"

    uglify:
      build:
        files:
          "build/js/lib.js" : [
            'bower_components/jquery/dist/jquery.js'
            'bower_components/angular/angular.js'
            'bower_components/angular-sanitize/angular-sanitize.js'
          ]

    sass:
      build:
        files:
          "tmp/css/styles.css" : "src/css/styles.sass"

    autoprefixer:
      options:
        browsers: ['last 2 versions', 'ie 9']

      build:
        src: "tmp/css/styles.css"
        dest: "build/css/styles.css"

    connect:
      server:
        options:
          port: 5000
          hostname: 'localhost'
          base: 'build'
          livereload: true

    karma:
      options:
        preprocessors:
          '**/*.coffee': ['coffee']
        frameworks: ['jasmine']
        files: [
          'bower_components/jquery/dist/jquery.js'
          'bower_components/angular/angular.js'
          'bower_components/angular-sanitize/angular-sanitize.js'
          'bower_components/angular-mocks/angular-mocks.js'
          'src/js/app.coffee'
          'test/**/*.coffee'
        ]
        reporters: ['progress']
      unit:
        options:
          singleRun: true
          browsers: ['PhantomJS']
      development:
        options:
          background: true
          browsers: ['PhantomJS']

    watch:
      karma:
        files:["src/js/app.coffee",'test/**/*.coffee']
        tasks: ['karma:development:run']
      coffee:
        files: ["src/js/app.coffee"]
        tasks: ["coffee:build"]
      sass:
        files: ["src/css/*.sass"]
        tasks: ["sass:build"]
      autoprefixer:
        files: ["tmp/css/styles.css"]
        tasks: ["autoprefixer:build"]
      reload:
        files: ["build/*.html","build/js/app.js"]
        options: {livereload: true}
      livereload:
        files: ["build/css/styles.css"]
        options: {livereload: true}
  }

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-sass'
  grunt.loadNpmTasks 'grunt-autoprefixer'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-karma'
  grunt.loadNpmTasks 'grunt-contrib-watch'


  grunt.registerTask 'live', ['karma:development:start', 'connect', 'watch']

  grunt.registerTask 'test', ['karma:unit']

  grunt.registerTask 'default', ['karma:unit', 'sass', 'autoprefixer', 'coffee']