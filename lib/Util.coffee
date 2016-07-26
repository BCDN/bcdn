exports = module.exports = class Util
  @generateId: -> "#{('0000000000' + Math.random().toString(10)).substr(-10)}"
  @generateToken: -> Math.random().toString(36).substr(2)
