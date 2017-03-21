# Licensed under http://creativecommons.org/licenses/by/3.0/
# Note: change were made to adapt this application.
#
# Credit: CoffeeScript Cookbook
# https://coffeescript-cookbook.github.io/chapters/classes_and_objects/mixins

# The mixin helper.
#
# @param [Class] base the base class.
# @param [Class] mixins more classes to be mixed.
# @return [Class] the mixed class.
mix = (base, mixins...) ->
  # @nodoc
  class Mixed extends base
  # earlier mixins override later ones.
  for mixin in mixins by -1
    for name, method of mixin::
      Mixed::[name] = method
  Mixed

exports = module.exports = mix
