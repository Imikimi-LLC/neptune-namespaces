{version} = require '../../package.json'
{log, upperCamelCase, fileWithoutExtension, peek, arrayWithoutLast} = require './MiniFoundation'
Path = require "path"

module.exports = class Helper
  @generatedByString:         "# generated by Neptune Namespaces v#{version[0]}.x.x"
  @globalNamespaceName:       "Neptune"
  @neptuneBaseClass:          "#{@globalNamespaceName}.Base"
  @shouldIgnore:              (itemName) -> !!itemName.match /^(\..*|index.coffee|namespace.coffee)$/
  @shouldNotNamespace:        (itemName) -> !!itemName.match /^-/
  @shouldIncludeInNamespace:  (file, namespaceName) -> toModuleName(file) == peek namespaceName.split '.'
  @toFilename:                (path) -> peek path.split('/')
  @toModuleName:              toModuleName = (itemName) -> upperCamelCase fileWithoutExtension itemName
  @requirePath: (filenameWithExtension) -> "./" + Path.parse(filenameWithExtension).name
