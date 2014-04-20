require 'forwardable'

module StaticSourceLoc
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
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

