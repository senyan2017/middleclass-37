local class = require 'middleclass'

describe('A Mixin', function()

  local Mixin1, Mixin2, Class1, Class2

  before_each(function()
    Mixin1, Mixin2 = {},{}

    function Mixin1:included(theClass) theClass.includesMixin1 = true end
    function Mixin1:foo() return 'foo' end
    function Mixin1:bar() return 'bar' end
    Mixin1.static = {}
    Mixin1.static.bazzz = function() return 'bazzz' end


    function Mixin2:baz() return 'baz' end

    Class1 = class('Class1'):include(Mixin1, Mixin2)
    function Class1:foo() return 'foo1' end

    Class2 = class('Class2', Class1)
    function Class2:bar2() return 'bar2' end
  end)

  it('invokes the "included" method when included', function()
    assert.is_true(Class1.includesMixin1)
  end)

  it('has all its functions (except "included") copied to its target class', function()
    assert.equal(Class1:bar(), 'bar')
    assert.is_nil(Class1.included)
  end)

  it('makes its functions available to subclasses', function()
    assert.equal(Class2:baz(), 'baz')
  end)

  it('allows overriding of methods in the same class', function()
    assert.equal(Class2:foo(), 'foo1')
  end)

  it('allows overriding of methods on subclasses', function()
    assert.equal(Class2:bar2(), 'bar2')
  end)

  it('makes new static methods available in classes', function()
    assert.equal(Class1:bazzz(), 'bazzz')
    assert.equal(Class2:bazzz(), 'bazzz')
  end)

end)

describe('Mixin Introspection', function()

  local MixinA, MixinB, MixinC
  local Root, Child, Grandchild

  before_each(function()
    MixinA = { name = 'MixinA' }
    function MixinA:a() return 'a' end

    MixinB = { name = 'MixinB' }
    function MixinB:b() return 'b' end
    MixinB.static = {}
    function MixinB.static.smethod() return 'smethod' end

    MixinC = { name = 'MixinC' }
    function MixinC:c() return 'c' end

    Root = class('Root')
    Root:include(MixinA)

    Child = class('Child', Root)
    Child:include(MixinB)

    Grandchild = class('Grandchild', Child)
    Grandchild:include(MixinC)
  end)

  describe('includesMixin', function()
    it('returns true for a directly included mixin', function()
      assert.is_true(Root:includesMixin(MixinA))
      assert.is_true(Child:includesMixin(MixinB))
      assert.is_true(Grandchild:includesMixin(MixinC))
    end)

    it('returns true for a mixin inherited from a parent class', function()
      assert.is_true(Child:includesMixin(MixinA))
      assert.is_true(Grandchild:includesMixin(MixinA))
      assert.is_true(Grandchild:includesMixin(MixinB))
    end)

    it('returns false for a mixin not included anywhere in the hierarchy', function()
      assert.is_false(Root:includesMixin(MixinB))
      assert.is_false(Root:includesMixin(MixinC))
      assert.is_false(Child:includesMixin(MixinC))
    end)

    it('returns false for non-table arguments', function()
      assert.is_false(Root:includesMixin(nil))
      assert.is_false(Root:includesMixin('MixinA'))
      assert.is_false(Root:includesMixin(42))
    end)

    it('works correctly with unrelated classes', function()
      local Other = class('Other')
      assert.is_false(Other:includesMixin(MixinA))
      Other:include(MixinA)
      assert.is_true(Other:includesMixin(MixinA))
    end)
  end)

  describe('mixins', function()
    it('returns only directly included mixins for a class', function()
      local rootMixins = Root:mixins()
      assert.equal(#rootMixins, 1)
      assert.equal(rootMixins[1], MixinA)
    end)

    it('does not return parent mixins for a subclass', function()
      local childMixins = Child:mixins()
      assert.equal(#childMixins, 1)
      assert.equal(childMixins[1], MixinB)
    end)

    it('returns an empty table for a class with no mixins', function()
      local Plain = class('Plain')
      local plainMixins = Plain:mixins()
      assert.equal(#plainMixins, 0)
    end)

    it('returns all directly included mixins when multiple are included', function()
      local Multi = class('Multi')
      Multi:include(MixinA, MixinB, MixinC)
      local multiMixins = Multi:mixins()
      assert.equal(#multiMixins, 3)
      -- Check all three are present (order not guaranteed with pairs)
      local found = {}
      for _, m in ipairs(multiMixins) do found[m] = true end
      assert.is_true(found[MixinA])
      assert.is_true(found[MixinB])
      assert.is_true(found[MixinC])
    end)

    it('returns a new table each call (not a reference to internal state)', function()
      local t1 = Root:mixins()
      local t2 = Root:mixins()
      assert.are_not.equal(t1, t2)
      assert.equal(#t1, #t2)
    end)
  end)

  describe('multiple mixin interactions', function()
    it('correctly tracks mixin included at different hierarchy levels', function()
      -- MixinA included at Root, MixinB at Child, MixinC at Grandchild
      -- Grandchild should see all three via includesMixin
      assert.is_true(Grandchild:includesMixin(MixinA))
      assert.is_true(Grandchild:includesMixin(MixinB))
      assert.is_true(Grandchild:includesMixin(MixinC))
      -- But mixins() only shows direct ones
      local gmixins = Grandchild:mixins()
      assert.equal(#gmixins, 1)
      assert.equal(gmixins[1], MixinC)
    end)

    it('does not report duplicate when same mixin is included at multiple levels', function()
      local Shared = {}
      function Shared:shared() return 'shared' end
      local A = class('A')
      A:include(Shared)
      local B = class('B', A)
      B:include(Shared)
      -- Both levels include it, includesMixin should return true
      assert.is_true(A:includesMixin(Shared))
      assert.is_true(B:includesMixin(Shared))
      -- B's own mixins should list it once
      local bmixins = B:mixins()
      assert.equal(#bmixins, 1)
    end)
  end)

end)

