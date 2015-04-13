--- Turbo.lua Mustache test
--
-- Copyright 2013 John Abrahamsen
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local turbo = require "turbo"

describe("turbo.web.Mustache Namespace", function()
    it("Basic usage", function()

    local simple_template = [[
<body>
    <h1>
        {{heading }}
    </h1>
    {{!

            Some comment section that
            even spans across multiple lines,
            that I just have to have to explain my flawless code.

    }}
    <h2>
        {{{desc}}} {{! No escape with triple mustaches allow HTML tags! }}
        {{&desc}} {{! No escape can also be accomplished by & char }}
    </h2>
    <p>I am {{age}} years old. What would {{you}} like to buy in my shop?</p>
    {{  #items }}  {{! I like spaces alot!      }}
        Item: {{item}}
        {{#types}}
            {{! Only print items if available.}}
            Type available: {{type}}
        {{/types}}
        {{^types}}  Only one type available.
        {{! Apparently only one type is available because types is not set,
        determined by the hat char ^}}
        {{/types}}
    {{/items}}

    {{^items}}
        No items available!
    {{/items}}
    {{{ >disclaimer   }}}       {{!! I like partials alot too. }}

</body>]]
        -- We basically rely on the fact that compile will throw error
        -- if the compiling is erroring on valid input.
        local tmpl = turbo.web.Mustache.compile(simple_template)
        local compiled_tmpl = turbo.web.Mustache.render(tmpl, {
            heading="My website!",
            desc="<b>Big important website</b>",
            age=27,
            items={
                {item="Bread",
                    types={
                        {type="light"},
                        {type="fatty"}
                    }
                },
                {item="Milk"},
                {item="Sugar"}
            }
            }, {disclaimer=[[Disclaimer for {{heading}}.]]})
    end)

    it("Support no whitespace in partial operator.", function()
        assert.equal(turbo.web.Mustache.render(
            "{{>disclaimer}}",
            {heading="My website"},
            {disclaimer=[[Disclaimer for {{{heading}}}.]]}), "Disclaimer for My website.")
    end)

    it("Support whitespace in partial operator.", function()
        assert.equal(turbo.web.Mustache.render(
            "{{> disclaimer}}{{! Whitespace between operator and name.}}",
            {heading="My website"},
            {disclaimer=[[Disclaimer for {{{heading}}}.]]}), "Disclaimer for My website.")
    end)

    it("Support whitespace before middle and after partial operator.", function()
        assert.equal(turbo.web.Mustache.render(
            "{{  >   disclaimer   }}",
            {heading="My website"},
            {disclaimer=[[Disclaimer for {{{heading}}}.]]}), "Disclaimer for My website.")
    end)

    it("Support whitespace before middle after key operator.", function()
        assert.equal(turbo.web.Mustache.render(
            "{{{  whitespacer        }}}",
            {whitespacer="My website"}), "My website")
    end)

    it("Support whitespace before middle after section operator.", function()
        assert.equal(turbo.web.Mustache.render(
            "{{  #test  }}Klein{{  /test     }}",
            {test="My website"}), "Klein")
    end)
end)