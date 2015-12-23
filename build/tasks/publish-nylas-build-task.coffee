_ = require 'underscore'
s3 = require 's3'
fs = require 'fs'
path = require 'path'
request = require 'request'
Promise = require 'bluebird'

s3Client = null
packageVersion = null
fullVersion = null

module.exports = (grunt) ->
  {cp, spawn, rm} = require('./task-helpers')(grunt)

  appName = -> grunt.config.get('nylasGruntConfig.appName')
  dmgName = -> "#{appName().split('.')[0]}.dmg"
  zipName = -> "#{appName().split('.')[0]}.zip"
  winReleasesName = -> "RELEASES"
  winSetupName = -> "Nylas N1Setup.exe"
  winNupkgName = -> "nylas-#{packageVersion}-full.nupkg"

  populateVersion = ->
    new Promise (resolve, reject) ->
      json = require(path.join(grunt.config.get('nylasGruntConfig.appDir'), 'package.json'))
      cmd = 'git'
      args = ['rev-parse', '--short', 'HEAD']
      spawn {cmd, args}, (error, {stdout}={}, code) ->
        return reject() if error
        commitHash = stdout?.trim?()
        packageVersion = json.version
        if packageVersion.indexOf('-') > 0
          fullVersion = packageVersion
        else
          fullVersion = "#{packageVersion}-#{commitHash}"
        resolve()

  runEmailIntegrationTest = ->
    return Promise.resolve() unless process.platform is 'darwin'

    buildDir = grunt.config.get('nylasGruntConfig.buildDir')
    new Promise (resolve, reject) ->
      appToRun = path.join(buildDir, appName())
      scriptToRun = "./build/run-build-and-send-screenshot.scpt"
      spawn
        cmd: "osascript"
        args: [scriptToRun, appToRun, fullVersion]
      , (error) ->
        if error
          reject(error)
          return
        resolve()

  postToSlack = (msg) ->
    return Promise.resolve() unless process.env.NYLAS_INTERNAL_HOOK_URL
    new Promise (resolve, reject) ->
      request.post
        url: process.env.NYLAS_INTERNAL_HOOK_URL
        json:
          username: "Edgehill Builds"
          text: msg
      , (err, httpResponse, body) ->
        return reject(err) if err
        resolve()

  put = (localSource, destName) ->
    grunt.log.writeln ">> Uploading #{localSource} to S3…"

    write = grunt.log.writeln
    ext = path.extname(destName)
    lastPc = 0

    new Promise (resolve, reject) ->
      uploader = s3Client.uploadFile
        localFile: localSource
        s3Params:
          Key: destName
          ACL: "public-read"
          Bucket: "edgehill"

      uploader.on "error", (err) ->
        reject(err)
      uploader.on "progress", ->
        pc = Math.round(uploader.progressAmount / uploader.progressTotal * 100.0)
        if pc isnt lastPc
          lastPc = pc
          write(">> Uploading #{destName} #{pc}%")
      uploader.on "end", (data) ->
        resolve(data)

  uploadToS3 = (filename, key) ->
    buildDir = grunt.config.get('nylasGruntConfig.buildDir')
    filepath = path.join(buildDir, filename)

    grunt.log.writeln ">> Uploading #{filename} to #{key}…"
    put(filepath, key).then (data) ->
      msg = "N1 release asset uploaded: <#{data.Location}|#{key}>"
      postToSlack(msg).then ->
        Promise.resolve(data)

  uploadZipToS3 = (filenameToZip, key) ->
    buildDir = grunt.config.get('nylasGruntConfig.buildDir')
    buildZipFilename = "#{filenameToZip}.zip"
    buildZipPath = path.join(buildDir, buildZipFilename)

    grunt.log.writeln ">> Creating zip file…"

    new Promise (resolve, reject) ->
      rm(buildZipPath)
      orig = process.cwd()
      process.chdir(buildDir)

      spawn
        cmd: "zip"
        args: ["-9", "-y", "-r", buildZipPath, filenameToZip]
      , (error) ->
        process.chdir(orig)
        if error
          reject(error)
          return

        grunt.log.writeln ">> Created #{buildZipPath}"
        uploadToS3(buildZipFilename, key).then(resolve).catch(reject)

  grunt.registerTask "publish-nylas-build", "Publish Nylas build", ->
    awsKey = process.env.AWS_ACCESS_KEY_ID ? ""
    awsSecret = process.env.AWS_SECRET_ACCESS_KEY ? ""

    if awsKey.length is 0
      grunt.fail.fatal "Please set the AWS_ACCESS_KEY_ID environment variable"
    if awsSecret.length is 0
      grunt.fail.fatal "Please set the AWS_SECRET_ACCESS_KEY environment variable"

    s3Client = s3.createClient
      s3Options:
        accessKeyId: process.env.AWS_ACCESS_KEY_ID
        scretAccessKey: process.env.AWS_SECRET_ACCESS_KEY

    done = @async()

    populateVersion()
    .then ->
      if process.env.RUN_APPLE_SCRIPT_INTEGRATION
        runEmailIntegrationTest()
      else Promise.resolve()
    .then ->
      uploadPromises = []
      if process.platform is 'darwin'
        uploadPromises.push uploadToS3(dmgName(), "#{fullVersion}/#{process.platform}/#{process.arch}/N1.dmg")
        uploadPromises.push uploadZipToS3(appName(), "#{fullVersion}/#{process.platform}/#{process.arch}/N1.zip")

      else if process.platform is 'win32'
        uploadPromises.push uploadToS3("installer/"+winReleasesName(), "#{fullVersion}/#{process.platform}/#{process.arch}/RELEASES")
        uploadPromises.push uploadToS3("installer/"+winSetupName(), "#{fullVersion}/#{process.platform}/#{process.arch}/N1Setup.exe")
        uploadPromises.push uploadToS3("installer/"+winNupkgName(), "#{fullVersion}/#{process.platform}/#{process.arch}/#{winNupkgName()}")

      else if process.platform is 'linux'
        buildDir = grunt.config.get('nylasGruntConfig.buildDir')
        files = fs.readdirSync(buildDir)
        for file in files
          if path.extname(file) is '.deb'
            uploadPromises.push uploadToS3(file, "#{fullVersion}/#{process.platform}/#{process.arch}/N1.deb")
          if path.extname(file) is '.rpm'
            uploadPromises.push uploadToS3(file, "#{fullVersion}/#{process.platform}/#{process.arch}/#{path.basename(file)}")

      else
        grunt.fail.fatal "Unsupported platform: '#{process.platform}'"

      Promise.all(uploadPromises).then(done).catch (err) ->
        grunt.log.error(err)
        return false
