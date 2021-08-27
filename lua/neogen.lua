local ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
assert(ok, "neogen requires nvim-treesitter to operate :(")

neogen = {}

-- Require utilities
neogen.utilities = {}
require("neogen.utilities.extractors")
require("neogen.utilities.nodes")

-- Require defaults
require("neogen.locators.default")
require("neogen.granulators.default")
require("neogen.generators.default")

neogen.generate = function(opts)
    opts = opts or {
        type = "func",
    }
    vim.treesitter.get_parser(0):for_each_tree(function(tree, language_tree)
        local language = neogen.configuration.languages[language_tree:lang()]

        if language then
            language.locator = language.locator or neogen.default_locator
            language.granulator = language.granulator or neogen.default_granulator
            language.generator = language.generator or neogen.default_generator

            if not language.parent[opts.type] or not language.data[opts.type] then
                return
            end

            -- Use the language locator to locate one of the required parent nodes above the cursor
            local located_parent_node = language.locator({
                root = tree:root(),
                current = ts_utils.get_node_at_cursor(0),
            }, language.parent[opts.type])

            if not located_parent_node then
                return
            end

            -- Use the language granulator to get the required content inside the node found with the locator
            local data = language.granulator(located_parent_node, language.data[opts.type])

            if data then
                -- Will try to generate the documentation from a template and the data found from the granulator
                local to_place, start_column, content = language.generator(
                    located_parent_node,
                    data,
                    language.template,
                    opts.type
                )

                if #content ~= 0 then
                    -- Append the annotation in required place
                    vim.fn.append(to_place, content)

                    -- Place cursor after annotations and start editing
                    if neogen.configuration.input_after_comment == true then
                        vim.fn.cursor(to_place + 1, start_column)
                        vim.api.nvim_command("startinsert!")
                    end
                end
            end
        end
    end)
end

function neogen.generate_command()
    vim.api.nvim_command('command! -range -bar Neogen lua require("neogen").generate()')
end

neogen.setup = function(opts)
    neogen.configuration = vim.tbl_deep_extend("keep", opts or {}, {
        input_after_comment = true,
        -- DEFAULT CONFIGURATION
        languages = {
            lua = require("neogen.configurations.lua"),
            python = require("neogen.configurations.python"),
            javascript = require("neogen.configurations.javascript"),
            c = require("neogen.configurations.c"),
        },
    })

    if neogen.configuration.enabled == true then
        neogen.generate_command()
    end
end

return neogen
