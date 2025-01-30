require 'tempfile'
require 'open3'
require 'json'

module Compiler

  class << self
    def compile(ruby)
      tokens = Tokenizer.new(ruby).tokenize
      tree = Parser.new(tokens).parse
      CodeGen.new(tree).gen
    end

    def format(js)
      Formatter.new(js).format
    end
  end

  class Tokenizer
    
    Token = Struct.new(:type, :value)
    TokenType = Struct.new(:regex, :type)

    TOKEN_TYPES = [
      TokenType.new(/\bdef\b/, :def),
      TokenType.new(/\bend\b/, :end),
      TokenType.new(/\bnil\b/, :nil),
      TokenType.new(/\b[a-zA-Z_][a-zA-Z0-9_]*\b/, :identifier),
      TokenType.new(/['"].*['"]/, :string),
      TokenType.new(/\b\d+\b/, :integer),
      TokenType.new(/\+/, :addition),
      TokenType.new(/\-/, :subtraction),
      TokenType.new(/\*/, :multiplication),
      TokenType.new(/\//, :division),
      TokenType.new(/=/, :assign),
      TokenType.new(/\(/, :oparen),
      TokenType.new(/\)/, :cparen),
      TokenType.new(/,/, :comma),
      TokenType.new(/\n/, :newl),
    ]

    def initialize(code)
      @code = trim_space(code)
    end

    def tokenize
      tokens = []

      while !@code.empty?
        token_found = false

        TOKEN_TYPES.each do |token_type|
          if @code =~ /\A(#{token_type.regex})/
            value = $1
            @code = @code[value.length..]
            tokens << Token.new(type: token_type.type, value:)
            token_found = true
            break
          end
        end

        if !token_found
          raise RuntimeError, "Couldn't match token on '#{@code}'"
        end

        @code = trim_space(@code)
      end

      tokens
    end

    private

    def trim_space(str)
      str.gsub(/^[^\S\n]+|[^\S\n]+$/, '') # leading and trailing whitespace (exluding \n)
    end
  end

  class Parser

    NodeDef            = Struct.new(:name, :args, :body)
    NodeNil            = Struct.new
    NodeString         = Struct.new(:value)
    NodeInteger        = Struct.new(:value)
    NodeCall           = Struct.new(:name, :args)
    NodeVarRef         = Struct.new(:value)
    NodeAddition       = Struct.new
    NodeSubtraction    = Struct.new
    NodeMultiplication = Struct.new
    NodeDivision       = Struct.new
    NodeAssign         = Struct.new
    NodeExpr           = Struct.new(:terms)
    NodeExprList       = Struct.new(:exprs)

    def initialize(tokens)
      @tokens = Marshal.load(Marshal.dump(tokens)) # deep dup
    end

    def parse
      tree = []

      while !@tokens.empty?
        tree << (
          if peek(:def)
            parse_def
          else
            parse_expr_list
          end
        )
      end

      tree
    end

    private

    def parse_def
      consume(:def)
      name = consume(:identifier).value
      args = parse_def_args
      consume_newls
      body = parse_expr_list
      consume(:end)
      consume_newls

      NodeDef.new(name:, args:, body:)
    end

    def parse_def_args
      args = []
      if !peek(:oparen)
        return args
      end

      expr = NodeExpr.new(terms: [])

      consume(:oparen)
      while peek(:identifier)
        expr.terms << NodeVarRef.new(value: consume(:identifier).value)

        if peek(:assign)
          consume(:assign)
          expr.terms << NodeAssign.new

          while !peek(:comma) && !peek(:cparen)
            expr.terms << parse_expr
          end
        end

        if peek(:comma)
          consume(:comma)
        end

        args << expr
        expr = NodeExpr.new(terms: [])
      end
      consume(:cparen)
      
      args
    end

    def parse_expr_list
      exprs = []
      terms = []

      while !peek(:def) && !peek(:end) && !@tokens.empty?
        terms << parse_expr

        if peek(:newl)
          exprs << NodeExpr.new(terms:)
          terms = []
          consume_newls
        end
      end

      if terms.length > 0
        exprs << NodeExpr.new(terms:)
      end

      NodeExprList.new(exprs:)
    end

    def parse_expr
      if peek(:nil)
        parse_nil
      elsif peek(:string)
        parse_string
      elsif peek(:integer)
        parse_integer
      elsif peek(:identifier) && peek(:oparen, 2)
        parse_call
      elsif peek(:identifier)
        parse_var_ref
      elsif peek(:addition)
        parse_addition
      elsif peek(:subtraction)
        parse_subtraction
      elsif peek(:multiplication)
        parse_multiplication
      elsif peek(:division)
        parse_division
      elsif peek(:assign)
        parse_assign
      else
        raise RuntimeError, "Unable to parse expr: \n#{JSON.pretty_generate(@tokens)}"
      end
    end

    def parse_nil
      consume(:nil)
      NodeNil.new
    end

    def parse_string
      NodeString.new(consume(:string).value.gsub(/['"]/, ''))
    end

    def parse_integer
      NodeInteger.new(consume(:integer).value.to_i)
    end

    def parse_call
      name = consume(:identifier).value
      args = parse_call_args
      NodeCall.new(name:, args:)
    end

    def parse_call_args
      args = []

      consume(:oparen)
      while !peek(:cparen)
        terms = []
        while !peek(:comma) && !peek(:cparen)
          terms << parse_expr
        end
        args << NodeExpr.new(terms:)

        if peek(:comma)
          consume(:comma)
        end
      end
      consume(:cparen)

      args
    end

    def parse_var_ref
      NodeVarRef.new(value: consume(:identifier).value)
    end

    def parse_addition
      consume(:addition)
      NodeAddition.new
    end

    def parse_subtraction
      consume(:subtraction)
      NodeSubtraction.new
    end

    def parse_multiplication
      consume(:mutliplication)
      NodeMultiplication.new
    end

    def parse_division
      consume(:division)
      NodeDivision.new
    end

    def parse_assign
      consume(:assign)
      NodeAssign.new
    end

    def peek(expected_type, depth = 1)
      token = @tokens[depth - 1] || return false
      token.type == expected_type
    end

    def consume(expected_type)
      token = @tokens.shift
      if token.type != expected_type
        raise RuntimeError, "Expected token type #{expected_type} but got #{token.type}"
      end
      token
    end

    def consume_newls
      while peek(:newl)
        consume(:newl)
      end
    end
  end

  class CodeGen
    def initialize(tree)
      @tree = tree
    end

    def gen
      js = String.new

      @tree.each do |node|
        js << (
          case node
          when Parser::NodeDef
            gen_def(node)
          when Parser::NodeExprList
            gen_expr_list_strs(node).join
          else
            raise RuntimeError, "Invalid top level node: #{node}"
          end
        )
      end

      js
    end

    private

    def gen_def(node)
      "function #{node.name}(#{node.args.map { gen_expr it }.join(', ')}) {\n#{gen_def_body(node.body)}}\n"
    end

    def gen_def_body(exprs)
      body = String.new

      strs = gen_expr_list_strs(exprs)
      strs.each_with_index do |str, i|
        body << (
          if i == strs.length - 1 && !str.include?('return')
            String.new('return ') << str
          else
            str
          end
        )
      end

      body
    end

    def gen_expr_list_strs(node)
      js_strs = []

      node.exprs.each do |expr|
        js_strs << (gen_expr(expr) << ";\n")
      end

      js_strs
    end

    def gen_expr(expr)
      js = String.new

      expr.terms.each_with_index do |term, i|
        js << (i == 0 ? '' : ' ') << (
          case term
          when Parser::NodeNil
            gen_nil(term)
          when Parser::NodeString
            gen_string(term)
          when Parser::NodeInteger
            gen_integer(term)
          when Parser::NodeCall
            gen_call(term)
          when Parser::NodeVarRef
            gen_var_ref(term)
          when Parser::NodeAddition
            gen_addition(term)
          when Parser::NodeSubtraction
            gen_subtraction(term)
          when Parser::NodeMultiplication
            gen_multiplication(term)
          when Parser::NodeDivision
            gen_division(term)
          when Parser::NodeAssign
            gen_assign(term)
          else
            raise ArgumentError, "Invalid term: #{term.inspect}"
          end
        )
      end

      js
    end

    def gen_nil(term)
      'null'
    end

    def gen_string(term)
      "'#{term.value}'"
    end

    def gen_integer(term)
      term.value.to_s
    end

    def gen_call(term)
      "#{term.name}(#{term.args.map { gen_expr it }.join(', ')})"
    end

    def gen_var_ref(term)
      term.value.to_s
    end

    def gen_addition(term)
      '+'
    end

    def gen_subtraction(term)
      '-'
    end

    def gen_multiplication(term)
      '*'
    end

    def gen_division(term)
      '/'
    end

    def gen_assign(term)
      '='
    end
  end

  class Formatter
    def initialize(js)
      @js = js
    end

    def format
      Tempfile.open(['temp', '.js']) do |file|
        file.write @js
        file.flush

        _out, err, status = Open3.capture3("npx prettier --write \"#{file.path}\"")
        if !status.success?
          raise SystemCallError, "Prettier error: #{err}"
        end

        file.rewind
        file.read.strip
      end
    end
  end
end