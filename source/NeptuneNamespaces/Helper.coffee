{version} = require '../../package.json'
{log, upperCamelCase, fileWithoutExtension, peek, arrayWithoutLast, pad} = require './MiniFoundation'
Path = require "path"
{max} = Math

module.exports = class Helper
  @generatedByStringBare:     "generated by Neptune Namespaces v#{version[0]}.x.x"
  @generatedByString:         "# #{@generatedByStringBare}"
  @globalNamespaceName:       "Neptune"
  @neptuneBaseClass:          "#{@globalNamespaceName}.Namespace"
  @PackageNamespaceClassName: "#{@globalNamespaceName}.PackageNamespace"
  @shouldNotAutoload:         (itemName) -> !!itemName.match /^([\._].*|(index|namespace)\.(coffee|js))$/
  @shouldNotNamespace:        (itemName) -> !!itemName.match /^-/
  @shouldIncludeInNamespace:  (file, namespaceName) -> toModuleName(file) == peek namespaceName.split '.'
  @toFilename:                (path) -> peek path.split('/')
  @toModuleName:              toModuleName = (itemName) -> upperCamelCase fileWithoutExtension itemName
  @requirePath: (filenameWithExtension) -> "./" + Path.parse(filenameWithExtension).name

  @alignColumns = ->
    listOfLists = []
    listOfLists = listOfLists.concat el for el in arguments

    maxLengths = []
    for line in listOfLists
      for cell, i in line
        maxLengths[i] = if i == line.length - 1
          cell
        else
          max (maxLengths[i] || 0), cell.length

    maxLengths[maxLengths - 1] = 0 # don't pad last column

    for line in listOfLists
      paddedCells = for cell, i in line
        pad cell, maxLengths[i]
      paddedCells.join ' '
