require_relative 'find_by_hash'
require_relative 'database_scoped'

module RCS
  module Money
    class Tx
      include Mongoid::Document
      include FindByHash
      include DatabaseScoped

      COLLECTION_NAME = 'tx'

      store_in(collection: COLLECTION_NAME)

      field :h, as: :hash, type: String
      field :i, as: :in,   type: Array, default: []
      field :o, as: :out,  type: Array, default: []

      index({hash: 1}, {unique: true})
    end
  end
end
