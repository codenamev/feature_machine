module FeatureMachine
  class WorkItemSpecSchema < Schematist::Schema
    string :title,
      description: "One line, 8-120 characters, naming the capability or fix in the product's own terms. Not a user quote."
    string :summary,
      description: "One or two sentences for the public roadmap: what will change for users, in plain language. No implementation detail."
    string :problem,
      description: "Who hits this and what they are trying to do. Ground it in the requests; cite how many distinct people asked."
    string :scope,
      description: "What is in, then an explicit 'Out of scope:' list for things that were asked for but should be separate work. Markdown bullets."
    string :acceptance_criteria,
      description: "Checkable statements of done, as a Markdown bullet list. Each one must be verifiable by someone who was not in the conversation."
  end
end
