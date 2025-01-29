require 'minitest/autorun'
require 'open3'

require_relative 'compiler.rb'
require_relative 'golden.rb'

UPDATE = ENV['UPDATE'] == 'true' # golden

Minitest::Test.make_my_diffs_pretty!

module Compiler
  class TestTokenizer < Minitest::Test
    def test_tokenize_var_dec
      expected = [
        Tokenizer::Token.new(type: :identifier, value: 'str'),
        Tokenizer::Token.new(type: :assign, value: '='),
        Tokenizer::Token.new(type: :string, value: '"string"'),
      ]

      actual = Tokenizer.new('str = "string"').tokenize

      assert_equal expected, actual
    end

    def test_tokenize_fun_def
      expected = [
        Tokenizer::Token.new(type: :def, value: 'def'),
        Tokenizer::Token.new(type: :identifier, value: 'fun'),
        Tokenizer::Token.new(type: :oparen, value: '('),
        Tokenizer::Token.new(type: :identifier, value: 'arg'),
        Tokenizer::Token.new(type: :cparen, value: ')'),
        Tokenizer::Token.new(type: :newl, value: "\n"),
        Tokenizer::Token.new(type: :end, value: 'end'),
      ]

      actual = Tokenizer.new("def fun(arg)\nend").tokenize

      assert_equal expected, actual
    end

    {
      'nil' => {
        ruby: 'nil',
        expected: [Tokenizer::Token.new(type: :nil, value: 'nil')]
      },
      'string_single_quote' => {
        ruby: "'str'",
        expected: [Tokenizer::Token.new(type: :string, value: "'str'")]
      },
      'string_double_quote' => {
        ruby: '"str"',
        expected: [Tokenizer::Token.new(type: :string, value: '"str"')]
      },
      'integer' => {
        ruby: '1',
        expected: [Tokenizer::Token.new(type: :integer, value: '1')]
      },
    }.each do |tt_name, tt|
      define_method("test_tokenize_primitive_#{tt_name}") do
        assert_equal tt[:expected], Tokenizer.new(tt[:ruby]).tokenize
      end
    end

    {
      '+' => {
        ruby: '+',
        expected: [Tokenizer::Token.new(type: :addition, value: '+')]
      },
      '-' => {
        ruby: '-',
        expected: [Tokenizer::Token.new(type: :subtraction, value: '-')]
      },
      '*' => {
        ruby: '*',
        expected: [Tokenizer::Token.new(type: :multiplication, value: '*')]
      },
      '/' => {
        ruby: '/',
        expected: [Tokenizer::Token.new(type: :division, value: '/')]
      },
      '=' => {
        ruby: '=',
        expected: [Tokenizer::Token.new(type: :assign, value: '=')]
      },
    }.each do |tt_name, tt|
      define_method("test_tokenize_operation_#{tt_name}") do
        assert_equal tt[:expected], Tokenizer.new(tt[:ruby]).tokenize
      end
    end
  end

  class TestParser < Minitest::Test
    def test_var_dec
      expected = [
        Parser::NodeExprList.new(exprs: [
          Parser::NodeExpr.new(terms: [
            Parser::NodeVarRef.new(value: 'str'),
            Parser::NodeAssign.new,
            Parser::NodeString.new(value: 'string'),
          ]),
        ])
      ]

      actual = Parser.new([
        Tokenizer::Token.new(type: :identifier, value: 'str'),
        Tokenizer::Token.new(type: :assign, value: '='),
        Tokenizer::Token.new(type: :string, value: '"string"'),
      ]).parse

      assert_equal expected, actual
    end

    def test_parse_fun_def_without_args
      expected = [
        Parser::NodeDef.new(name: 'fun', args: [], body: Parser::NodeExprList.new(exprs: []))
      ]

      actual = Parser.new([
        Tokenizer::Token.new(type: :def, value: 'def'),
        Tokenizer::Token.new(type: :identifier, value: 'fun'),
        Tokenizer::Token.new(type: :newl, value: "\n"),
        Tokenizer::Token.new(type: :end, value: "end"),
      ]).parse

      assert_equal expected, actual
    end

    def test_parse_fun_def_with_args
      expected = [
        Parser::NodeDef.new(
          name: 'fun',
          args: [
            Parser::NodeExpr.new(terms: [Parser::NodeVarRef.new(value: 'arg1')]),
            Parser::NodeExpr.new(terms: [Parser::NodeVarRef.new(value: 'arg2')]),
          ],
          body: Parser::NodeExprList.new(exprs: [])
        )
      ]

      actual = Parser.new([
        Tokenizer::Token.new(type: :def, value: 'def'),
        Tokenizer::Token.new(type: :identifier, value: 'fun'),
        Tokenizer::Token.new(type: :oparen, value: '('),
        Tokenizer::Token.new(type: :identifier, value: 'arg1'),
        Tokenizer::Token.new(type: :comma, value: ','),
        Tokenizer::Token.new(type: :identifier, value: 'arg2'),
        Tokenizer::Token.new(type: :cparen, value: ')'),
        Tokenizer::Token.new(type: :newl, value: "\n"),
        Tokenizer::Token.new(type: :end, value: "end"),
      ]).parse

      assert_equal expected, actual
    end

    {
      'nil' => {
        arg_tokens: [Tokenizer::Token.new(type: :nil, value: 'nil')],
        arg_parsed: [Parser::NodeNil.new]
      },
      'string' => {
        arg_tokens: [Tokenizer::Token.new(type: :string, value: 'str')],
        arg_parsed: [Parser::NodeString.new(value: 'str')]
      },
      'integer' => {
        arg_tokens: [Tokenizer::Token.new(type: :integer, value: '1')],
        arg_parsed: [Parser::NodeInteger.new(value: 1)]
      },
      'expr_fun_call' => {
        arg_tokens: [
          Tokenizer::Token.new(type: :identifier, value: 'fun'),
          Tokenizer::Token.new(type: :oparen, value: '('),
          Tokenizer::Token.new(type: :cparen, value: ')'),
        ],
        arg_parsed: [Parser::NodeCall.new(name: 'fun', args: [])]
      },
      'expr_operation' => {
        arg_tokens: [
          Tokenizer::Token.new(type: :integer, value: '1'),
          Tokenizer::Token.new(type: :addition, value: '+'),
          Tokenizer::Token.new(type: :integer, value: '2'),
        ],
        arg_parsed: [
          Parser::NodeInteger.new(value: 1),
          Parser::NodeAddition.new,
          Parser::NodeInteger.new(value: 2),
        ],
      }
    }.each do |tt_name, tt|
      define_method("test_parse_fun_def_with_arg_default_#{tt_name}") do
        expected = [
          Parser::NodeDef.new(
            name: 'fun',
            args: [Parser::NodeExpr.new(terms: [
              Parser::NodeVarRef.new(value: 'arg'),
              Parser::NodeAssign.new,
              *tt[:arg_parsed],
            ])],
            body: Parser::NodeExprList.new(exprs: [])
          )
        ]

        actual = Parser.new([
          Tokenizer::Token.new(type: :def, value: 'def'),
          Tokenizer::Token.new(type: :identifier, value: 'fun'),
          Tokenizer::Token.new(type: :oparen, value: '('),
          Tokenizer::Token.new(type: :identifier, value: 'arg'),
          Tokenizer::Token.new(type: :assign, value: '='),
          *tt[:arg_tokens],
          Tokenizer::Token.new(type: :cparen, value: ')'),
          Tokenizer::Token.new(type: :newl, value: "\n"),
          Tokenizer::Token.new(type: :end, value: "end"),
        ]).parse

        assert_equal expected, actual
      end
    end
  end

  class TestCodeGen < Minitest::Test
    def test_gen_var_dec
      expected = "str = 'string';\n"

      actual = CodeGen.new([
        Parser::NodeExprList.new(exprs: [
          Parser::NodeExpr.new(terms: [
            Parser::NodeVarRef.new(value: 'str'),
            Parser::NodeAssign.new,
            Parser::NodeString.new(value: 'string'),
          ]),
        ])
      ]).gen

      assert_equal expected, actual
    end

    def test_gen_fun_def_without_args
      expected = "function fun() {\n}\n"

      actual = CodeGen.new([
        Parser::NodeDef.new(name: 'fun', args: [], body: Parser::NodeExprList.new(exprs: []))
      ]).gen

      assert_equal expected, actual
    end

    def test_gen_fun_def_with_args
      expected = "function fun(arg1, arg2) {\n}\n"

      actual = CodeGen.new([
        Parser::NodeDef.new(
          name: 'fun',
          args: [
            Parser::NodeExpr.new(terms: [Parser::NodeVarRef.new(value: 'arg1')]),
            Parser::NodeExpr.new(terms: [Parser::NodeVarRef.new(value: 'arg2')]),
          ],
          body: Parser::NodeExprList.new(exprs: [])
        )
      ]).gen

      assert_equal expected, actual
    end
  end

  class TestCompiler < Minitest::Test

    FILE_SHA_STORE = Golden::FileShaStore.new

    Golden::FileLocator.new.golden_files.each do |golden|
      define_method("test_compile_#{golden}") do
        rb_path = File.expand_path("testdata/rb/#{golden}.rb")
        js_path = File.expand_path("testdata/js/#{golden}.js")

        rb = File.read(rb_path)
        if !FILE_SHA_STORE.match?(rb_path, rb)
          Golden::SyntaxValidator.ensure_valid_rb(rb)
          FILE_SHA_STORE.update(rb_path, rb)
        end

        js = Compiler.compile(rb)
        if !FILE_SHA_STORE.match?(js_path, js)
          Golden::SyntaxValidator.ensure_valid_js(js)
          FILE_SHA_STORE.update(js_path, js)
        end

        if UPDATE || !File.exist?(js_path)
          File.write(js_path, js)
        end

        assert_equal File.read(js_path), js
      end
    end
  end
end