--- Turbo.lua Mustache test
--
-- Copyright 2013, 2026 John Abrahamsen
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

    it("should render number values without escaping (triple mustache)", function()
        assert.equal(turbo.web.Mustache.render(
            "count={{{n}}}", {n=42}), "count=42")
    end)

    it("should render number values", function()
        assert.equal(turbo.web.Mustache.render(
            "I am {{age}} years old.", {age=27}),
            "I am 27 years old.")
        assert.equal(turbo.web.Mustache.render(
            "{{>p}}", {n=7}, {p="n={{n}}"}), "n=7")
    end)

    it("should skip a falsey section that contains a nested section", function()
        assert.equal(turbo.web.Mustache.render(
            "{{#missing}}{{#inner}}x{{/inner}}LEAK{{/missing}}TAIL", {}),
            "TAIL")
    end)

    it("should propagate safe mode into partials", function()
        assert.has_error(function()
            turbo.web.Mustache.render("{{>p}}", {}, {p="{{missing}}"}, true)
        end)
        assert.has_no.errors(function()
            turbo.web.Mustache.render("{{>p}}", {}, {p="{{missing}}"})
        end)
    end)

    it("should call a function value and render its result", function()
        assert.equal(turbo.web.Mustache.render(
            "Hello {{name}}!", {name=function() return "World" end}),
            "Hello World!")
    end)

    it("should escape the result of a function value ({{x}})", function()
        assert.equal(turbo.web.Mustache.render(
            "{{html}}", {html=function() return "<b>" end}),
            "&lt;b&gt;")
    end)

    it("should not escape the result of a function value ({{{x}}})", function()
        assert.equal(turbo.web.Mustache.render(
            "{{{html}}}", {html=function() return "<b>" end}),
            "<b>")
    end)

    it("should call a function value inside a partial", function()
        assert.equal(turbo.web.Mustache.render(
            "{{>p}}", {name=function() return "Bob" end}, {p="Hi {{name}}"}),
            "Hi Bob")
    end)
end)