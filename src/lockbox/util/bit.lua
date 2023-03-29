return {
    band    = function(l, r)    return l & r end,
    bor     = function(l, r)    return l | r end,
    bxor    = function(l, r)    return l ~ r end,
    bnot    = function(u)       return ~u end,
    lshift  = function(l, r)    return l << r end,
    rshift  = function(l, r)    return l >> r end,

    lrotate = function(l, r)
        l = l & 0xffffffff
        r = r & 0x1f
        return ((l << r) & 0xffffffff) | (l >> (32 - r))
    end,
    rrotate = function(l, r)
        l = l & 0xffffffff
        r = r & 0x1f
        return (l >> r) | (0xffffffff & (l << (32 - r)))
    end,
}
