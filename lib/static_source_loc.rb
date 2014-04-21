require 'forwardable'
require 'find'
require 'ruby_parser'

module StaticSourceLoc
	VERSION = '0.0.1'

	SourceLoc = Struct.new :file, :line

	class Source
		extend Forwardable

		attr_reader :name, :parent, :source_locs

		def initialize(name, parent)
			@name, @parent = name, parent
			@source_locs = []
		end

		def new_loc(file, line)
			source_locs << SourceLoc[file, line]
			self
		end

		def source_loc
			source_locs.first
		end

		delegate [:file, :line] => :source_loc

		def to_s
			qualname
		end

		def inspect
			"#<#{self.class.class_name}: #{qualname}>"
		end
	end

	class ModuleSource < Source
		attr_reader :submodules, :methods

		def initialize(name, parent, singleton=false)
			super name, parent
			@singleton = singleton
			@submodules, @methods = {}, {}
		end

		def singleton?
			@singleton
		end

		def new_submodule(name)
			@submodules[name] ||= ModuleSource.new name, self
		end

		def new_method(name)
			@methods[name] ||= MethodSource.new name, self
		end

		def singleton_class
			@singleton_class ||=
				ModuleSource.new :singleton_class, self, true
		end

		def qualname
			unless singleton?
				"#{parent.qualname if parent}::#{name}"
			else
				"#{parent.qualname if parent}.#{name}"
			end
		end

		def to_hash
			children = []
			children.concat(submodules.values)
			children.concat(methods.values)
			children << @singleton_class if @singleton_class
			children.each_with_object({qualname => self}) do |child, hash|
				hash[child.qualname] = child
				hash.merge! child.to_hash if child.respond_to? :to_hash
			end
		end

		def process_code(sexpr)
			case sexpr.node_type
			when :block
				sexpr.values.each &method(:process_code)
			when :class, :module
				new_submodule(sexpr[1]).
					new_loc(sexpr.file, sexpr.line).
					process_code(s(:block).concat sexpr.drop(3))
			when :sclass
				if sexpr[1] == s(:self)
					singleton_class.
						new_loc(sexpr.file, sexpr.line).
						process_code(s(:block).concat sexpr.drop(2))
				end
			when :defn
				new_method(sexpr[1]).
					new_loc(sexpr.file, sexpr.line)
			when :defs
				if sexpr[1] == s(:self)
					singleton_class.
						new_method(sexpr[2]).
						new_loc(sexpr.file, sexpr.line)
				end
			end
			self
		end
	end

	class MethodSource < Source
		def qualname
			unless parent and parent.singleton?
				"#{parent ? parent.qualname : 'Object'}##{name}"
			else
				"#{parent.parent.qualname if parent.parent}.#{name}"
			end
		end
	end

	Parser = RubyParser.new

	class << self
		def analyze(dir, file_test=nil, dir_test=nil, ignore_errors=true)
			file_test ||= /\.rb\Z/
			dir_test  ||= proc {true}
			sexprs = load_sexprs(dir, file_test, dir_test, ignore_errors)
			toplevel = ModuleSource.new :Object, nil
			sexprs.each &toplevel.method(:process_code)
			toplevel
		end

		private

		def load_sexprs(dir, file_test, dir_test, ignore_errors)
			files = Find.to_enum(:find, dir).each_with_object([]) do |path, files|
				if File.file? path
					next unless file_test === path
					files << path
				else
					Find.prune unless dir_test === path
				end
			end
			sexprs = files.map do |fn|
				File.open fn do |file|
					begin
						Parser.parse file.read
					rescue RubyParser::SyntaxError, Racc::ParseError
						raise unless ignore_errors
					end
				end
			end
			sexprs.compact!
			sexprs
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

