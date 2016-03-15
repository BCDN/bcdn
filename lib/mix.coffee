# Licensed under http://creativecommons.org/licenses/by/3.0/
# Note: change were made to adapt this application.
#
# Credit: CoffeeScript Cookbook
# https://coffeescript-cookbook.github.io/chapters/classes_and_objects/mixins

exports = module.exports = (base, mixins...) ->
  class Mixed extends base
  for mixin in mixins by -1 #earlier mixins override later ones
    for name, method of mixin::
      Mixed::[name] = method
  Mixed
