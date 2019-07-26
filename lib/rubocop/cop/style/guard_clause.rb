# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # Use a guard clause instead of wrapping the code inside a conditional
      # expression
      #
      # @example
      #   # bad
      #   def test
      #     if something
      #       work
      #     end
      #   end
      #
      #   # good
      #   def test
      #     return unless something
      #     work
      #   end
      #
      #   # also good
      #   def test
      #     work if something
      #   end
      #
      #   # bad
      #   if something
      #     raise 'exception'
      #   else
      #     ok
      #   end
      #
      #   # good
      #   raise 'exception' if something
      #   ok
      class GuardClause < Cop
        include MinBodyLength

        MSG = 'Use a guard clause (`%<example>s`) instead of wrapping the ' \
              'code inside a conditional expression.'

        def on_def(node)
          body = node.body

          return unless body

          if body.if_type?
            check_ending_if(body)
          elsif body.begin_type? && body.children.last.if_type?
            check_ending_if(body.children.last)
          end
        end
        alias on_defs on_def

        def on_if(node)
          return if accepted_form?(node)

          guard_clause_in_if = node.if_branch&.guard_clause?
          guard_clause_in_else = node.else_branch&.guard_clause?
          guard_clause = guard_clause_in_if || guard_clause_in_else
          return unless guard_clause

          kw = if guard_clause_in_if
                 node.loc.keyword.source
               else
                 opposite_keyword(node)
               end
          register_offense(node, "#{guard_clause.source} #{kw}")
        end

        private

        def check_ending_if(node)
          return if accepted_form?(node, true) || !min_body_length?(node)

          register_offense(node, "return #{opposite_keyword(node)}")
        end

        def opposite_keyword(node)
          node.if? ? 'unless' : 'if'
        end

        def register_offense(node, example)
          condition, = node.node_parts
          example += " #{condition.source}"
          add_offense(node,
                      location: :keyword,
                      message: format(MSG, example: example))
        end

        def accepted_form?(node, ending = false)
          accepted_if?(node, ending) || node.condition.multiline?
        end

        def accepted_if?(node, ending)
          return true if node.modifier_form? || node.ternary?

          if ending
            node.else?
          else
            !node.else? || node.elsif?
          end
        end
      end
    end
  end
end
