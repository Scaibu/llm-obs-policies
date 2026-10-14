**Rules you can't enforce mechanically get ignored.** [Likely] A 45-rule list in a wiki gets skimmed once and violated within a month. Roughly half of these can be enforced by linters and compiler flags, and I've marked those **[Enforce]**. Do that, or treat the rest as advice.

**Part 1: Gate (before writing anything generic)**

1. **Write the concrete version first.** [Certain] Generic code derived from a working concrete case is correct far more often than generic code designed up front.
2. **Require three real uses before abstracting.** [Certain] The rule of three. Two similar pieces of code can still diverge.
3. **Abstract behavior, not appearance.** [Likely] If two things look alike but change for different reasons, keep them separate. Merging them couples unrelated changes.
4. **State the required capability in one sentence.** [Likely] For example, "anything totally ordered" or "anything iterable once". If you can't, you haven't understood the problem yet.
5. **Don't use generics for a closed set of types.** [Likely] If the valid types are `int | string | Date`, use a union or enum. Generics are for open sets.
6. **If the generic version is harder to read than the concrete one, ship the concrete one.** [Likely] A new teammate should understand it in 5 minutes.

**Part 2: Constraints**

7. **Every type parameter gets the narrowest bound that compiles.** [Certain] Examples: `T: Ord`, `T extends Comparable<T>`, `where T: Hashable`.
8. **Never assume an undeclared capability.** [Certain] That covers equality, ordering, hashing, copying, defaults, and non-nullability.
9. **Never inspect the concrete type inside generic code.** [Certain] No `instanceof`, `typeof` switches, reflection, or `is T`. If you branch on type, split into overloads or separate functions. **[Enforce]**
10. **No escape hatches.** [Certain] That means no `any`, `Object`, `void*`, `interface{}`, `unsafe`, or unchecked casts. If one is truly unavoidable, isolate it in one function with a comment proving soundness. **[Enforce]**
11. **Never construct a `T` from nothing.** [Likely] No `new T()` or implicit defaults. Take a factory or an explicit default as a parameter.
12. **Take the narrowest input, return the most specific output.** [Certain] Accept an iterable, not a list, and a reader, not a file. Return the concrete type so callers lose nothing.

**Part 3: Type parameters**

13. **Every type parameter appears at least twice in the signature.** [Likely] A parameter used once relates nothing to anything. It's `unknown` with extra syntax. **[Enforce]** (some linters flag this)
14. **Output types must derive from input types.** [Certain] If the return type is unrelated to `T`, the generic is decorative.
15. **Max 2 type parameters per unit, 3 as an absolute ceiling.** [Likely] Beyond that, split it.
16. **Name by role when there's more than one.** [Likely] Use `TKey`, `TValue`, `TError`. Bare `T` is only for a single parameter.
17. **No default type parameters** unless needed for backward compatibility. [Likely] They hide a decision from the caller and degrade inference.
18. **Don't force callers to write explicit type arguments.** [Likely] If inference fails in normal use, the signature is wrong.

**Part 4: Semantics**

19. **Declare variance explicitly where the language allows.** [Certain] Producers are covariant, consumers are contravariant, and mutable containers are invariant. Getting this wrong causes unsound code (Java arrays, TypeScript method bivariance).
20. **Never mutate a value of generic type, and never assume ownership.** [Certain] Document whether you copy, borrow, move, or alias.
21. **Don't depend on identity or reference equality.** [Likely] It breaks with primitives, interned values, and immutable copies.
22. **Handle nullable, optional, unit, and `never` types explicitly.** [Certain] `find` returning `T | null` is ambiguous when `T` can be null. Use `Option<T>` or a result type.
23. **Make invalid states unrepresentable.** [Certain] Use enums, sum types, and validated constructors instead of runtime checks where possible.
24. **No boolean or mode flags that switch behavior.** [Likely] `process(x, legacy=True, strict=False)` is several functions pretending to be one.
25. **Equality, ordering, and hashing must be consistent with each other.** [Certain] If `a == b` then `hash(a) == hash(b)`, and the ordering must be total and transitive. Violating this corrupts sorted and hashed structures silently.

**Part 5: Runtime behavior**

26. **Misuse must fail at compile time, not runtime.** [Certain] If a bad type compiles then throws, your bounds are too weak.
27. **Deterministic given inputs.** [Certain] Inject time, randomness, I/O, and config. No hidden globals or singletons.
28. **Validate at the boundary once, then trust internally.** [Certain] Raise specific errors with context. Never swallow exceptions or return sentinel values like `-1` or `null` for failure.
29. **Define behavior for empty, single-element, and maximum-size inputs.** [Certain] Document it, don't leave it to emerge.
30. **Thread safety is documented, never implied.** [Certain] State whether the unit is safe for concurrent use, and what a caller must synchronize.
31. **No I/O, logging, or side effects inside generic utility code** unless that's its declared purpose. [Likely]

**Part 6: API design**

32. **Name by what it does, not where it's used.** [Certain] `retry_with_backoff`, not `retry_payment_call`. A domain name means it isn't generic yet.
33. **Hide generic complexity behind concrete aliases in public APIs.** [Likely] Export `UserRepo`, not `Repo<User, UserId, UserFilter, UserError>`.
34. **Prefer composition of small functions over one generic class with hooks.** [Likely] Avoid deep hierarchies and "template method" patterns.
35. **Document the contract, not the implementation.** [Certain] That means preconditions, postconditions, complexity, errors, ownership, and thread safety.
36. **Never break the contract in a minor version.** [Certain] Loosening a bound is compatible. Tightening one, adding a type parameter, or changing variance is a breaking change.
37. **Know your cost model.** [Certain] Monomorphization (Rust, C++) gives speed but bloats binaries. Erasure (Java) means boxing and no runtime type info. Dynamic dispatch has call overhead. Measure before claiming generics are free.

**Part 7: Testing**

38. **Test against a type matrix, not one type.** [Certain] Minimum set:
   - a primitive
   - a reference type
   - a nullable or optional type
   - a unit or empty type
   - a function type
   - a nested generic (`List<List<T>>`)
   - a type with custom equality or ordering
   - a type that is expensive or impossible to copy
39. **Add compile-time rejection tests.** [Likely] Use `@ts-expect-error`, `static_assert`, `trybuild`, or `compile_fail` doctests to prove invalid types are rejected. **[Enforce]**
40. **Use property-based tests for algebraic laws.** [Likely] Examples are `sort` idempotence, `map` identity and composition, and `decode(encode(x)) == x`.
41. **Test empty, single, and very large inputs for every container-like generic.** [Certain]
42. **Test error paths as thoroughly as success paths.** [Certain]

**Part 8: Maintenance**

43. **Delete unused generality.** [Likely] If no caller uses a parameter, hook, or bound after a few months, remove it.
44. **Every generic unit has a named owner and a written reason it exists.** [Likely] "Used by A, B, C" in the doc comment. When callers drop to one, inline it.
45. **Review generic code with a second reviewer** who didn't write it. [Likely] Authors are the worst judges of whether the abstraction is readable.
46. **Treat any generic unit with more than 5 call-site workarounds as broken.** [Guessing] The threshold is my heuristic, but the principle holds: workarounds at call sites mean the abstraction is wrong, so fix it or remove it.

**Minimum enforcement setup** [Likely]
- Ban `any`/`unsafe`/casts via linter (rules 9, 10)
- Compiler strict mode on (rules 22, 26)
- Compile-fail tests in CI (rule 39)
- A required type-matrix test file per generic module (rule 38)
