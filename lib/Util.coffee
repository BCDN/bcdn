# Utility class for ID or token generation.
class Util
  # Generate ID for peer or tracker nodes.
  #
  # @return [String] a generated ID.
  @generateId: -> "#{('0000000000' + Math.random().toString(10)).substr(-10)}"

  # Generate token for peer re-connection.
  #
  # @return [String] a generated token.
  @generateToken: -> Math.random().toString(36).substr(2)

exports = module.exports = Util
