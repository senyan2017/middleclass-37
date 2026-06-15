local class = require 'middleclass'

describe('Mixin duplicate include protection', function()

  describe('when the same mixin is included twice into the same class', function()
    local Mixin, hookCallCount, TheClass

    before_each(function()
      hookCallCount = 0
      Mixin = {}
      function Mixin:included(theClass)
        hookCallCount = hookCallCount + 1
        theClass.hookCallCount = hookCallCount
      end
      function Mixin:greet() return 'hello from mixin' end
      Mixin.static = {}
      Mixin.static.classMethod = function() return 'static' end

      TheClass = class('TheClass')
      TheClass:include(Mixin)
    end)

    it('fires the included hook exactly once on first include', function()
      assert.equal(1, hookCallCount)
      assert.equal(1, TheClass.hookCallCount)
    end)

    it('does NOT fire the included hook again on second include', function()
      TheClass:include(Mixin)
      assert.equal(1, hookCallCount, 'included hook should not fire again')
      assert.equal(1, TheClass.hookCallCount, 'class state should not be modified again')
    end)

    it('does NOT fire the included hook on third include either', function()
      TheClass:include(Mixin)
      TheClass:include(Mixin)
      assert.equal(1, hookCallCount)
    end)

    it('still has working methods after duplicate include', function()
      TheClass:include(Mixin)
      local inst = TheClass:new()
      assert.equal('hello from mixin', inst:greet())
      assert.equal('static', TheClass:classMethod())
    end)

    it('returns the class for chaining even on duplicate', function()
      local result = TheClass:include(Mixin)
      assert.equal(TheClass, result)
    end)
  end)

  describe('when a mixin with side-effect initialization is included twice', function()
    local CounterMixin, TheClass

    before_each(function()
      CounterMixin = { _includeCount = 0 }
      function CounterMixin:included(theClass)
        -- Simulate side-effect: incrementing a counter on the class
        theClass.initCounter = (theClass.initCounter or 0) + 1
      end
      function CounterMixin:doStuff() return 'stuff' end

      TheClass = class('TheClass')
    end)

    it('keeps side-effect initialization idempotent', function()
      TheClass:include(CounterMixin)
      assert.equal(1, TheClass.initCounter)

      -- Second include should be a no-op
      TheClass:include(CounterMixin)
      assert.equal(1, TheClass.initCounter, 'counter should NOT be incremented again')

      -- Third include should also be a no-op
      TheClass:include(CounterMixin)
      assert.equal(1, TheClass.initCounter, 'counter should still be 1')
    end)
  end)

  describe('when a parent includes a mixin and the subclass explicitly includes it too', function()
    local Mixin, parentHookCalls, childHookCalls, Parent, Child

    before_each(function()
      parentHookCalls = 0
      childHookCalls = 0
      Mixin = {}
      function Mixin:included(theClass)
        if theClass == Parent then
          parentHookCalls = parentHookCalls + 1
          theClass.parentHookCalls = parentHookCalls
        elseif theClass == Child then
          childHookCalls = childHookCalls + 1
          theClass.childHookCalls = childHookCalls
        end
      end
      function Mixin:mixinMethod() return 'from mixin' end
      Mixin.static = {}
      Mixin.static.mixinStatic = function() return 'mixin static' end

      Parent = class('Parent')
      Parent:include(Mixin)
      Child = class('Child', Parent)
    end)

    it('fires the hook once for the parent', function()
      assert.equal(1, parentHookCalls)
      assert.equal(1, Parent.parentHookCalls)
    end)

    it('allows the subclass to explicitly include the same mixin', function()
      -- The subclass has its own __includedMixins table, so it is allowed
      Child:include(Mixin)
      assert.equal(1, childHookCalls, 'hook should fire for the subclass')
      assert.equal(1, Child.childHookCalls)
    end)

    it('still blocks duplicate include on the subclass after the first explicit include', function()
      Child:include(Mixin)
      assert.equal(1, childHookCalls)

      -- Second include on child should be a no-op
      Child:include(Mixin)
      assert.equal(1, childHookCalls, 'hook should NOT fire twice on the subclass')
    end)

    it('does not affect the parent when the subclass includes the mixin', function()
      Child:include(Mixin)
      assert.equal(1, parentHookCalls, 'parent hook count should not change')
    end)

    it('subclass still inherits mixin methods even without explicit include', function()
      -- Even without Child:include(Mixin), methods are inherited
      local inst = Child:new()
      assert.equal('from mixin', inst:mixinMethod())
      assert.equal('mixin static', Child:mixinStatic())
    end)

    it('subclass can override mixin methods after explicit include', function()
      Child:include(Mixin)
      function Child:mixinMethod() return 'child override' end
      local inst = Child:new()
      assert.equal('child override', inst:mixinMethod())
      -- Parent is not affected
      local parentInst = Parent:new()
      assert.equal('from mixin', parentInst:mixinMethod())
    end)
  end)

  describe('when multiple mixins are included in a single call with duplicates', function()
    local MixinA, MixinB, hookCountA, hookCountB, TheClass

    before_each(function()
      hookCountA = 0
      hookCountB = 0
      MixinA = {}
      function MixinA:included(theClass) hookCountA = hookCountA + 1 end
      function MixinA:methodA() return 'A' end

      MixinB = {}
      function MixinB:included(theClass) hookCountB = hookCountB + 1 end
      function MixinB:methodB() return 'B' end

      TheClass = class('TheClass')
    end)

    it('applies each mixin once on first include', function()
      TheClass:include(MixinA, MixinB)
      assert.equal(1, hookCountA)
      assert.equal(1, hookCountB)
    end)

    it('skips already-included mixins in a repeated multi-include call', function()
      TheClass:include(MixinA, MixinB)
      TheClass:include(MixinA, MixinB)
      assert.equal(1, hookCountA)
      assert.equal(1, hookCountB)
    end)

    it('applies only the new mixin when mixing known and new mixins', function()
      TheClass:include(MixinA)
      assert.equal(1, hookCountA)
      assert.equal(0, hookCountB)

      TheClass:include(MixinA, MixinB)
      assert.equal(1, hookCountA, 'MixinA should not be re-applied')
      assert.equal(1, hookCountB, 'MixinB should be applied once')
    end)
  end)

  describe('method override behavior is preserved with dedup', function()
    local Mixin, TheClass

    before_each(function()
      Mixin = {}
      function Mixin:foo() return 'mixin foo' end
      function Mixin:bar() return 'mixin bar' end

      TheClass = class('TheClass')
      TheClass:include(Mixin)
    end)

    it('allows the class to override mixin methods', function()
      function TheClass:foo() return 'class foo' end
      local inst = TheClass:new()
      assert.equal('class foo', inst:foo())
      assert.equal('mixin bar', inst:bar())
    end)

    it('duplicate include does not re-override class methods with mixin methods', function()
      function TheClass:foo() return 'class foo' end
      -- Re-include should be a no-op, so the class override stays
      TheClass:include(Mixin)
      local inst = TheClass:new()
      assert.equal('class foo', inst:foo(), 'class override should still win')
    end)
  end)

  describe('mixin with static fields is idempotent on duplicate include', function()
    local Mixin, staticInitCount, TheClass

    before_each(function()
      staticInitCount = 0
      Mixin = {}
      Mixin.static = {}
      Mixin.static.sharedValue = 42
      function Mixin:included(theClass)
        staticInitCount = staticInitCount + 1
        -- Simulate one-time static setup
        theClass.staticSetupDone = true
      end

      TheClass = class('TheClass')
      TheClass:include(Mixin)
    end)

    it('applies static fields on first include', function()
      assert.equal(42, TheClass.sharedValue)
      assert.is_true(TheClass.staticSetupDone)
      assert.equal(1, staticInitCount)
    end)

    it('does not re-run included hook or re-apply static on duplicate', function()
      TheClass:include(Mixin)
      assert.equal(42, TheClass.sharedValue)
      assert.equal(1, staticInitCount, 'static init should not run again')
    end)
  end)

  describe('two different classes can independently include the same mixin', function()
    local Mixin, hookTargets, ClassA, ClassB

    before_each(function()
      hookTargets = {}
      Mixin = {}
      function Mixin:included(theClass)
        hookTargets[#hookTargets + 1] = theClass.name
      end
      function Mixin:shared() return 'shared' end

      ClassA = class('ClassA')
      ClassB = class('ClassB')
    end)

    it('fires the hook independently for each class', function()
      ClassA:include(Mixin)
      ClassB:include(Mixin)
      assert.equal(2, #hookTargets)
      assert.equal('ClassA', hookTargets[1])
      assert.equal('ClassB', hookTargets[2])
    end)

    it('blocks duplicate on each class independently', function()
      ClassA:include(Mixin)
      ClassB:include(Mixin)
      ClassA:include(Mixin)
      ClassB:include(Mixin)
      assert.equal(2, #hookTargets, 'hooks should only fire once per class')
    end)
  end)

  describe('grandparent-parent-child mixin include chain', function()
    local Mixin, hookLog, GrandParent, Parent, Child

    before_each(function()
      hookLog = {}
      Mixin = {}
      function Mixin:included(theClass)
        hookLog[#hookLog + 1] = theClass.name
      end
      function Mixin:mixinFn() return 'mixin' end

      GrandParent = class('GrandParent')
      GrandParent:include(Mixin)
      Parent = class('Parent', GrandParent)
      Child = class('Child', Parent)
    end)

    it('hook fires only for the class that explicitly includes', function()
      assert.equal(1, #hookLog)
      assert.equal('GrandParent', hookLog[1])
    end)

    it('child inherits mixin methods without hook firing', function()
      local inst = Child:new()
      assert.equal('mixin', inst:mixinFn())
      assert.equal(1, #hookLog, 'no extra hook calls for inheritance')
    end)

    it('child can explicitly include and hook fires once for child', function()
      Child:include(Mixin)
      assert.equal(2, #hookLog)
      assert.equal('Child', hookLog[2])

      -- Duplicate on child is blocked
      Child:include(Mixin)
      assert.equal(2, #hookLog, 'no duplicate hook on child')
    end)

    it('parent can also explicitly include without affecting grandparent or child', function()
      Parent:include(Mixin)
      assert.equal(2, #hookLog)
      assert.equal('Parent', hookLog[2])

      -- Grandparent count unchanged
      local gpCount = 0
      for _, name in ipairs(hookLog) do
        if name == 'GrandParent' then gpCount = gpCount + 1 end
      end
      assert.equal(1, gpCount)
    end)
  end)

end)
