describe("Homie utils", function()

  local U

  setup(function()
    U = require "homie.utils"
  end)


  describe("slugify", function()

    it("slugifies a name to lower-case", function()
      assert.equal("hello", U.slugify("Hello"))
    end)


    it("removes leading unallowed chars", function()
      assert.equal("hello", U.slugify("###Hello"))
    end)


    it("removes leading digits", function()
      assert.equal("hello", U.slugify("123Hello"))
    end)


    it("removes trailing unallowed chars", function()
      assert.equal("hello", U.slugify("Hello###"))
    end)


    it("leaves trailing digits", function()
      assert.equal("hello123", U.slugify("Hello123"))
    end)


    it("replaces unallowed characters with '-'", function()
      assert.equal("hello-world", U.slugify("hello_world"))
    end)


    it("replaces multiple '-' with 1", function()
      assert.equal("hello-world", U.slugify("Hello-###-World"))
    end)


    it("does it all...", function()
      assert.equal("hello-world-999", U.slugify("!@#123HELLO%%%%###-World##999$$$"))
    end)


    it("returns error if nothing left", function()
      local ok, err = U.slugify("###")
      assert.equal("cannot slugify '###', no valid characters left", err)
      assert.falsy(ok)
    end)

  end)

end)
