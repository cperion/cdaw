-- tests/schema_doc_sugar.t
-- Doc-comment sugar and bare doc string forms should attach to semantic nodes.

import "lib/schema"

local function expect_parse_error(src, pattern)
    local fn, err = terralib.loadstring(src)
    assert(fn == nil, "expected parse error")
    if not err:match(pattern) then
        error(("expected error matching %q, got:\n%s"):format(pattern, err))
    end
end

--- Schema documentation from attached doc comments.
local schema DocSugarDemo
    --- Decl phase documentation from attached doc comments.
    phase Decl
        --- Node record documentation from attached doc comments.
        record Node
            --- Stable semantic id from attached doc comments.
            id: string
        end

        --- Expr enum documentation from attached doc comments.
        enum Expr
            --- Literal variant documentation from attached doc comments.
            Lit { value: number doc "Literal numeric value from bare doc sugar." }

            --- Negative variant documentation from attached doc comments.
            Neg { inner: Expr doc [[Nested expression from bare block doc sugar.]] }
        end

        --- Public lowering methods from attached doc comments.
        methods
            --- Lower a node into output form.
            Node:lower(tag: string doc "Suffix tag.") -> Out.Node
                impl = function(self, tag)
                    return types.Out.Node(self.id .. tag)
                end
        end
    end

    --- Output phase documentation from attached doc comments.
    phase Out
        doc [[Output phase documentation from bare block doc sugar.]]

        record Node
            doc "Output node documentation from bare string doc sugar."
            id: string doc "Output stable id."
        end
    end

    hooks Runtime.Grouped
        doc [[Nested runtime hook documentation from bare block doc sugar.]]

        --- Resolve missing runtime methods lazily.
        methodmissing
            macro = function(name, obj, ...)
                return `0
            end
    end
end

assert(DocSugarDemo.doc == "Schema documentation from attached doc comments.")
assert(DocSugarDemo.ast.phases[1].doc == "Decl phase documentation from attached doc comments.")
assert(DocSugarDemo.ast.phases[1].decls[1].doc == "Node record documentation from attached doc comments.")
assert(DocSugarDemo.ast.phases[1].decls[1].fields[1].doc == "Stable semantic id from attached doc comments.")
assert(DocSugarDemo.ast.phases[1].decls[2].doc == "Expr enum documentation from attached doc comments.")
assert(DocSugarDemo.ast.phases[1].decls[2].variants[1].doc == "Literal variant documentation from attached doc comments.")
assert(DocSugarDemo.ast.phases[1].decls[2].variants[1].fields[1].doc == "Literal numeric value from bare doc sugar.")
assert(DocSugarDemo.ast.phases[1].decls[2].variants[2].doc == "Negative variant documentation from attached doc comments.")
assert(DocSugarDemo.ast.phases[1].decls[2].variants[2].fields[1].doc == "Nested expression from bare block doc sugar.")
assert(DocSugarDemo.ast.phases[1].decls[3].doc == "Public lowering methods from attached doc comments.")
assert(DocSugarDemo.ast.phases[1].decls[3].items[1].doc == "Lower a node into output form.")
assert(DocSugarDemo.ast.phases[1].decls[3].items[1].args[1].doc == "Suffix tag.")
assert(DocSugarDemo.ast.phases[2].doc == "Output phase documentation from bare block doc sugar.")
assert(DocSugarDemo.ast.phases[2].decls[1].doc == "Output node documentation from bare string doc sugar.")
assert(DocSugarDemo.ast.phases[2].decls[1].fields[1].doc == "Output stable id.")
assert(DocSugarDemo.ast.hooks[1].doc == "Nested runtime hook documentation from bare block doc sugar.")
assert(DocSugarDemo.ast.hooks[1].items[1].doc == "Resolve missing runtime methods lazily.")

local lowered = DocSugarDemo.types.Decl.Node("root"):lower("-x")
assert(DocSugarDemo.types.Out.Node:isclassof(lowered))
assert(lowered.id == "root-x")

assert(DocSugarDemo.surface:find('doc = "Schema documentation from attached doc comments%."') ~= nil)
assert(DocSugarDemo.surface:find('doc = "Output phase documentation from bare block doc sugar%."') ~= nil)
assert(DocSugarDemo.surface:find('doc = "Output node documentation from bare string doc sugar%."') ~= nil)
assert(DocSugarDemo.surface:find('doc = "Resolve missing runtime methods lazily%."') ~= nil)
assert(DocSugarDemo.surface:find('doc = "Suffix tag%."') ~= nil)

assert(DocSugarDemo.markdown:find('Schema documentation from attached doc comments.', 1, true) ~= nil)
assert(DocSugarDemo.markdown:find('Output phase documentation from bare block doc sugar.', 1, true) ~= nil)
assert(DocSugarDemo.markdown:find('Resolve missing runtime methods lazily.', 1, true) ~= nil)
assert(DocSugarDemo.markdown:find('Suffix tag.', 1, true) ~= nil)

local loaded = assert(terralib.loadstring([=[
import "lib/schema"

local schema StringBackedDocDemo
    doc "String-backed schema documentation."

    phase Decl
        doc [[Decl phase documentation.]]

        record Node
            doc "Node record documentation."
            id: string doc "Stable semantic id."
        end
    end
end

return StringBackedDocDemo
]=]))()

assert(loaded.doc == "String-backed schema documentation.")
assert(loaded.ast.phases[1].doc == "Decl phase documentation.")
assert(loaded.ast.phases[1].decls[1].doc == "Node record documentation.")
assert(loaded.ast.phases[1].decls[1].fields[1].doc == "Stable semantic id.")

expect_parse_error([[
import "lib/schema"

local schema MissingDocDemo
    doc "This bare doc sugar enables unified-doc mode."

    phase Decl
        record Node
            id: string
        end
    end
end
]], "phase 'Decl' must declare non%-empty doc")

print("schema doc sugar test passed")
