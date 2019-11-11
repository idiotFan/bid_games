require 'fast_jsonapi'

class VoteSerializer
    include FastJsonapi::ObjectSerializer
    # set_id :created_at

    # set_id do 
    #     nil
    # end
    set_type :vote
    attributes :voted_by, :voted_key, :created_at
  end