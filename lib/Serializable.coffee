# Serializable interface, act as a default serializer.
class Serializable
  # Default method to serialize an arbitrary object to a JSON-encoded string.
  #
  # @param [Object] obj arbitrary object to be serialized.
  # @return [String] JSON-encoded string that contains the serialized object.
  serialize: (obj) -> JSON.stringify obj
  # Default method to deserialize a JSON-encoded string back to the object.
  #
  # @param [String] data JSON-encoded string to be deserialized.
  # @return [Object] the object parsed from the JSON-encoded string.
  deserialize: (data) -> JSON.parse data

exports = module.exports = Serializable
