class Query < BaseQuery
  include Mongoid::Document

  embeds_many :executions, class_name: 'Execution', inverse_of: :query

  belongs_to :user
  has_many :events
  has_and_belongs_to_many :endpoints
  
  before_save :generate_map_reduce # noop unless generated?
  
  def last_execution
    executions.desc(:time).first
  end

  def execute(should_notify = false)
    # add an execution to the query with the current run time and if the user wants to be notified by email on completion
    execution = Execution.new(time: Time.now.to_i, notification: should_notify)
    self.executions << execution
    self.save!

    execution.execute()
  end

  def generate_map_reduce
    if (self.generated?)
      base_map = CoffeeScript.compile(Rails.root.join(QueryComposer::Application.paths['app/assets'][0], 'javascripts','builder','base_map.js.coffee').read, :bare => true)
      self.map = base_map
      self.reduce = 'blah'
    end
  end
  
end

