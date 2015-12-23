fs = require 'fs'
path = require 'path'
_ = require 'underscore'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  fillTemplate = (filePath, data) ->
    template = _.template(String(fs.readFileSync("#{filePath}.in")))
    filled = template(data)

    outputPath = path.join(grunt.config.get('nylasGruntConfig.buildDir'), path.basename(filePath))
    grunt.file.write(outputPath, filled)
    outputPath

  getInstalledSize = (buildDir, callback) ->
    cmd = 'du'
    args = ['-sk', path.join(buildDir, 'Nylas')]
    spawn {cmd, args}, (error, {stdout}) ->
      installedSize = stdout.split(/\s+/)?[0] or '200000' # default to 200MB
      callback(null, installedSize)

  grunt.registerTask 'mkdeb', 'Create debian package', ->
    done = @async()
    buildDir = grunt.config.get('nylasGruntConfig.buildDir')

    if process.arch is 'ia32'
      arch = 'i386'
    else if process.arch is 'x64'
      arch = 'amd64'
    else
      return done("Unsupported arch #{process.arch}")

    {name, version, description} = grunt.file.readJSON('package.json')
    section = 'devel'
    maintainer = 'Nylas Team <support@nylas.com>'
    installDir = '/usr'
    iconName = 'nylas'

    appFileName = grunt.config.get('nylasGruntConfig.appFileName')
    linuxShareDir = grunt.config.get('nylasGruntConfig.linuxShareDir')

    getInstalledSize buildDir, (error, installedSize) ->
      data = {name, version, description, section, arch, maintainer, installDir, iconName, installedSize, appFileName, linuxShareDir}
      controlFilePath = fillTemplate(path.join('build', 'resources', 'linux', 'debian', 'control'), data)
      desktopFilePath = fillTemplate(path.join('build', 'resources', 'linux', 'nylas.desktop'), data)
      icon = path.join('build', 'resources', 'nylas.png')
      postinstFilePath  = path.join('build', 'resources', 'linux', 'debian', 'postinst')
      postrmFilePath = path.join('build', 'resources', 'linux', 'debian', 'postrm')

      cmd = path.join('script', 'mkdeb')
      args = [version, arch, controlFilePath, desktopFilePath, icon, postinstFilePath, postrmFilePath, buildDir]
      spawn {cmd, args}, (error) ->
        if error?
          done(error)
        else
          grunt.log.ok "Created #{buildDir}/nylas-#{version}-#{arch}.deb"
          done()
