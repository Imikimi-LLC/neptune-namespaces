colors = require "colors"
glob = require "glob"
fsp = require "fs-promise"
{upperCamelCase, peek, pushIfUnique, indent, pad, log, withoutTrailingSlash, promiseSequence} = require "./tools"
{max} = Math

module.exports = class Generator
  @generate: (globRoot, options = {}) ->
    new Promise (resolve) ->
      glob globRoot, {}, (er, files) ->
        filePromiseGenerators = for file in files when fsp.statSync(file).isDirectory()
          do (file) -> ->
            generator = new Generator file, options

            generator.generate()
            .then ->
              Generator.watch file, options if options.watch

        promiseSequence filePromiseGenerators

  @watch: (root, options) ->
    @log root, "watching: ".green + root.yellow
    fsp.watch root, {persistent: true, recursive: true}, (event, filename) =>
      if !filename.match /(^|\/)(namespace|index)\.coffee$/
        @log "watch event: ".bold.yellow + "#{event} #{filename.yellow}"

        generator = new Generator root, options
        generator.generate()

  @generatedByString: "# generated by Neptune Namespaces"
  @neptuneGlobalName: "Neptune"
  @neptuneGlobalInitializer: "require 'neptune-namespaces'"
  """
    self.#{@neptuneGlobalName} ||= class #{@neptuneGlobalName}
      @namespacePath: "#{@neptuneGlobalName}"
      @Base: class Base
        @namespacePath: "#{@neptuneGlobalName}.Base"
        @namespace: "#{@neptuneGlobalName}"
        @classes: []
        @namespaces: []
        @finishLoad: (classes, namespaces)->
          @classes = @classes.concat classes
          @namespaces = @namespaces.concat namespaces
          for name in classes when klass = @[name]
            klass.namespace = @
            klass.namespacePath = @namespacePath + "." + klass

    """
  @neptuneBaseClass: "#{@neptuneGlobalName}.Base"

  @log: (root, args...) ->
    args = args.join()
    args = args.split "\n"
    for arg in args
      console.log if arg == ""
        ""
      else
        "NN (#{root}): ".grey + arg

  log: (args...) -> Generator.log @root, args.join()

  constructor: (@root, options = {}) ->
    {@pretend, @verbose} = options
    # map from directory paths to list of coffee files in that directory
    @rootArray = @root.split "/"
    @directoriesWithCoffee = {}
    @generatedFileNames = ["index.coffee", "namespace.coffee"]

  addCoffeeFile: (fileWithPath) ->
    fileWithPathArray = fileWithPath.split "/"
    @addCoffeePathArrayAndFile(
      fileWithPathArray.slice 0, fileWithPathArray.length - 1
      peek(fileWithPathArray).split(/\.coffee$/)[0]
    )

  addCoffeePathArrayAndFile: (pathArray, file, subdir) ->

    path = pathArray.join '/'

    if pathArray.length > 1 && @root != path
      parentPathArray = pathArray.slice 0, pathArray.length - 1
      @addCoffeePathArrayAndFile parentPathArray, null, peek pathArray

    @directoriesWithCoffee[path] ||= files:[], subdirs:[]
    @directoriesWithCoffee[path].namespacePath = (upperCamelCase namespace for namespace in pathArray.slice (@rootArray.length - 1)).join '.'
    # pushIfUnique @directoriesWithCoffee[path].files, "index.coffee"
    pushIfUnique @directoriesWithCoffee[path].files, file if file
    pushIfUnique @directoriesWithCoffee[path].subdirs, subdir if subdir

  prettyPrint: (path = @root, indent = "") ->
    unless pathInfo = @directoriesWithCoffee[path]
      @log "path not found: #{path}".red
      return

    dirName = peek path.split '/'
    @log (indent + upperCamelCase dirName).yellow
    indent += "  "
    for subdir in pathInfo.subdirs
      @prettyPrint path + "/" + subdir, indent
    for file in pathInfo.files
      @log indent + upperCamelCase file.split(/\.coffee$/)[0]

  getNameSpaceNamesFromPath: (path) ->
    [..., parentNameSpaceName, nameSpaceName] = path.split('/')
    nameSpaceName = upperCamelCase nameSpaceName
    parentNameSpaceName = null if path == @root
    if parentNameSpaceName
      parentNameSpaceName = upperCamelCase parentNameSpaceName
      requireParentNameSpace = "#{parentNameSpaceName} = require '../namespace'"
      parentNameSpaceName += "."

    parentNameSpaceName: (parentNameSpaceName && upperCamelCase parentNameSpaceName) || Generator.neptuneGlobalName
    nameSpaceName: nameSpaceName && upperCamelCase nameSpaceName
    requireParentNameSpace: requireParentNameSpace || Generator.neptuneGlobalInitializer
    requireNameSpace: "#{nameSpaceName} = require './namespace'"


  generateIndex: (path, {files, subdirs}) ->
    upperCamelCaseNames = []
    {parentNameSpaceName, nameSpaceName, requireNameSpace} = @getNameSpaceNamesFromPath path

    requireFiles = {}
    requireFilesOrder = [nameSpaceName]
    requireFiles[nameSpaceName] = 'namespace'

    for subdir in subdirs
      requireFiles[name = nameSpaceName + "." + upperCamelCase subdir] = subdir
      requireFilesOrder.push name
    for file in files
      requireFiles[name = nameSpaceName + "." + upperCamelCase file] =  file
      requireFilesOrder.push name

    maxLength = 0
    maxLength = max maxLength, ucName.length for ucName in requireFilesOrder


    requires = for upperCamelCaseName in requireFilesOrder
      file = requireFiles[upperCamelCaseName]
      "#{pad upperCamelCaseName, maxLength} = require './#{file}'"

    result = """
    #{Generator.generatedByString}
    # this file: #{path}/index.coffee

    module.exports =
    #{requires.join "\n"}
    """

    if files.length > 0 || subdirs.length > 0
      result +=
        """

        #{nameSpaceName}.finishLoad(
          #{JSON.stringify (upperCamelCase file for file in files)}
        )
        """
    result

  getNamespacePath: (path) ->
    path.split(@root)[1]

  generateNamespace: (path, {files, subdirs, namespacePath}) ->
    {parentNameSpaceName, nameSpaceName, requireParentNameSpace} = @getNameSpaceNamesFromPath path

    children = (upperCamelCase file for file in files)
    for dir in subdirs
      children.push upperCamelCase dir

    result = """
      #{Generator.generatedByString}
      # file: #{path}/namespace.coffee

      #{requireParentNameSpace}
      module.exports = #{parentNameSpaceName}.#{nameSpaceName} ||
      class #{parentNameSpaceName}.#{nameSpaceName} extends #{Generator.neptuneBaseClass}
        @namespace: #{parentNameSpaceName}
        @namespacePath: "#{Generator.neptuneGlobalName}.#{namespacePath}"

      #{parentNameSpaceName}.addNamespace #{parentNameSpaceName}.#{nameSpaceName}
      """
    result

  generateHelper: ({name, code}) ->
    if @pretend
      @log "\ngenerated: #{name.yellow}"
      @log indent code.green
    @generatedFiles[name] = code

  writeFiles: ->
    promises = for name, code of @generatedFiles
      @log "writing: #{name.yellow}"
      fsp.writeFile name, code
    Promise.all promises

  generateFiles: ->
    @generatedFiles = {}
    for path, pathInfo of @directoriesWithCoffee
      @generateHelper
        name: "#{path}/namespace.coffee"
        code: @generateNamespace path, pathInfo

      @generateHelper
        name: "#{path}/index.coffee"
        code: @generateIndex path, pathInfo

  generateFromFiles: (files) =>
    for file in files when !file.match /(namespace|index)\.coffee$/
      @addCoffeeFile file
    if @verbose
      @log "generating namespace structure:"
      @log "  Neptune".yellow
      @prettyPrint @root, "    "
    @generateFiles()
    if @pretend
      Promise.resolve()
    else
      @writeFiles()

  generate: ->
    new Promise (resolve, reject) =>
      @log "\nscanning root: #{@root.yellow}" if @verbose
      glob "#{@root}/**/*.coffee", {}, (er, files) =>
        if er
          reject()
        else
          resolve if files.length == 0
            @log "  no .coffee files found".yellow.bold
          else
            @generateFromFiles files
