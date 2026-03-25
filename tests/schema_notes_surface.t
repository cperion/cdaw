-- tests/schema_notes_surface.t
-- Unified docs and stripped surface export should preserve authored contract text.

import "lib/schema"

local schema NotesDemo
    doc = [[Top schema documentation.]]

    phase Decl
        doc = [[Decl phase documentation.]]

        record Node
            doc = [[Node record documentation.]]
            id: string doc = [[Stable semantic id.]]
        end

        methods
            doc = [[Decl public methods.]]
            Node:lower() -> Out.Node
                doc = [[Lower node to output node.]]
                impl = function(self)
                    return types.Out.Node(self.id)
                end
        end
    end

    phase Out
        doc = [[Output phase documentation.]]
        record Node
            doc = [[Output node documentation.]]
            id: string
        end
    end
end

assert(NotesDemo.line ~= nil)
assert(NotesDemo.doc == "Top schema documentation.")
assert(NotesDemo.ast.phases[1].line ~= nil)
assert(NotesDemo.ast.phases[1].doc == "Decl phase documentation.")
assert(NotesDemo.ast.phases[1].decls[1].line ~= nil)
assert(NotesDemo.ast.phases[1].decls[1].doc == "Node record documentation.")
assert(NotesDemo.ast.phases[1].decls[1].fields[1].doc == "Stable semantic id.")
assert(NotesDemo.ast.phases[1].decls[2].doc == "Decl public methods.")
assert(NotesDemo.ast.phases[2].doc == "Output phase documentation.")
assert(NotesDemo.ast.phases[2].decls[1].doc == "Output node documentation.")

local m = NotesDemo.methods[1]
assert(m.line ~= nil)
assert(m.doc == "Lower node to output node.")
assert(m.has_doc == true)
assert(m.category == "method_boundary")

assert(NotesDemo.surface:find('schema NotesDemo', 1, true) ~= nil)
assert(NotesDemo.surface:find('doc = "Top schema documentation."', 1, true) ~= nil)
assert(NotesDemo.surface:find('doc = "Decl phase documentation."', 1, true) ~= nil)
assert(NotesDemo.surface:find('doc = "Node record documentation."', 1, true) ~= nil)
assert(NotesDemo.surface:find('Stable semantic id.', 1, true) ~= nil)
assert(NotesDemo.surface:find('doc = "Decl public methods."', 1, true) ~= nil)
assert(NotesDemo.surface:find('Node:lower%(%) %-%> Out%.Node') ~= nil)
assert(NotesDemo.surface:find('doc = "Lower node to output node."', 1, true) ~= nil)
assert(NotesDemo.surface:find('doc = "Output phase documentation."', 1, true) ~= nil)
assert(NotesDemo.surface:find('doc = "Output node documentation."', 1, true) ~= nil)
assert(NotesDemo.surface:find('note =', 1, true) == nil)
assert(NotesDemo.surface:find('impl', 1, true) == nil)
assert(NotesDemo.surface:find('fallback', 1, true) == nil)
assert(NotesDemo.surface:find('status', 1, true) == nil)

assert(NotesDemo.markdown:find('# NotesDemo', 1, true) ~= nil)
assert(NotesDemo.markdown:find('Top schema documentation.', 1, true) ~= nil)
assert(NotesDemo.markdown:find('## Phase `Decl`', 1, true) ~= nil)
assert(NotesDemo.markdown:find('### Record `Decl.Node`', 1, true) ~= nil)
assert(NotesDemo.markdown:find('Stable semantic id.', 1, true) ~= nil)
assert(NotesDemo.markdown:find('#### `Node:lower%(%).*Out%.Node`') ~= nil)
assert(NotesDemo.markdown:find('Lower node to output node.', 1, true) ~= nil)
assert(NotesDemo.markdown:find('Output phase documentation.', 1, true) ~= nil)
assert(NotesDemo.markdown:find('Output node documentation.', 1, true) ~= nil)
assert(NotesDemo.markdown:find('category: `method_boundary`', 1, true) ~= nil)
assert(NotesDemo.markdown:find('memoized: `true`', 1, true) ~= nil)

print("schema notes/surface test passed")
