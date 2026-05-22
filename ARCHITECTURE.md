# Dunge Language Architecture

This note records the core design decisions for Dunge's authored story
language. The goal is to keep Dunge small while making non-trivial
choice-based interactive fiction possible.

## Core Principle

Dunge stories are data ASTs. The Common Lisp DSL may provide convenient
constructors and macros, but those forms must build inspectable AST objects.
They must not embed arbitrary Lisp code, closures, or runtime thunks.

This keeps the same story usable by multiple passes:

- a console interpreter;
- a validator;
- a future compiler, likely to JavaScript through Parenscript or a similar
  backend.

Save files also depend on this boundary. A game can eventually be saved as
text, including non-sexp formats such as JSON, because both authored stories
and runtime state are data.

## State

Persistent play state should be owned by the game runtime, not by Lisp dynamic
bindings. A small state record is enough for the next slice:

```lisp
(defstruct dunge-state
	current-room
	return-stack
	(globals (make-hash-table :test 'equal))
	(taken-choices (make-hash-table :test 'equal)))
```

Global state is the first-class primitive for flags, counters, and simple
inventory-like facts. Existing entity-local state can continue to exist, but
the reusable primitive layer should be expressed in terms of state operations,
not story-specific verbs.

Suggested primitive AST constructors:

```lisp
(state-ref :global :recipe)
(state-set :global :recipe t)
(state-clear :global :recipe)
(state-inc :global :coins 1)
(state-dec :global :coins 1)
(state-toggle :global :door-open)
```

Convenience constructors can build those primitives:

```lisp
(have? :recipe)		; => state-ref
(gain :recipe)		; => state-set true
(lose :recipe)		; => state-clear
```

The important part is that `have?`, `gain`, and `lose` are not special runtime
Lisp calls. They are authoring helpers that produce AST data.

## Planned Conditional Content

The current implementation keeps `shown-when` as the conditional content node.
The next content primitive should be `branch`, because paired conditions often
need an else branch without repeating the condition:

```lisp
(branch (have? :recipe)
	:then ((option "Cook stew" (goto "victory")))
	:else ((p "You'd cook, but you don't know what.")))
```

This avoids shadowing Common Lisp `if`, and it does not need a separate
paragraph-level `progn`: each branch already owns a list of AST nodes.

Once `branch` exists, `shown-when` can remain as compatibility/convenience
sugar and `shown-unless` can be added as matching sugar:

```lisp
(shown-when condition body...)
	; branch with only :then

(shown-unless condition body...)
	; branch with (not condition) and only :then
```

The branch node should be handled by the same generic passes as other nodes.
During rendering/choice collection, it evaluates its condition and visits
either the then children or the else children.

## Effects And Sequences

Choices often need to mutate state and then navigate. A choice target should
therefore be allowed to be a single control node or a sequence node:

```lisp
(sequence
	(gain :recipe)
	(back))
```

`sequence` is an effect/control AST node, not Lisp `progn`. It executes its
children in order and stops when a child produces a control result such as
`goto`, `gosub`, `back`, or `quit`.

## Example

The north-star kitchen example becomes:

```lisp
(game
	(room "kitchen"
		(p "It's a kitchen. A pot sits on the stove.")

		(branch (have? :recipe)
			:then ((option "Cook stew" (goto "victory")))
			:else ((p "You'd cook, but you don't know what.")))

		(choice
			("Search the cupboard" (gosub "cupboard"))
			("Leave" (goto "hallway"))))

	(room "cupboard"
		(p "Old shelves, dust.")
		(option "Take the recipe card"
			(sequence
				(gain :recipe)
				(back))
			:once t
			:id :take-recipe))

	(room "hallway"
		(p "A hallway."))

	(room "victory"
		(p "You cooked. You win.")
		(option "Quit" (quit))))
```

## Choices

Choices remain the only player interaction primitive. Dunge does not need
Twine-style inline links. Removing links keeps the AST, renderer, validator,
and future compiler simpler.

Choice visibility and persistence should be data:

```lisp
(option "Take the recipe card"
	(sequence
		(gain :recipe)
		(back))
	:when (not (have? :recipe))
	:once t
	:id :take-recipe)
```

Default choices are sticky. A once-only choice is hidden after it is selected.
The runtime records consumed choices in `taken-choices`, keyed by stable choice
IDs. Validation should require explicit IDs for once-only choices, or generate
stable IDs and make the policy clear.

## CLOS Passes

CLOS generic functions are the preferred way to implement interpreters and
compilers over the AST. Each pass dispatches on node classes and slots rather
than on embedded code.

Likely generic functions:

```lisp
(defgeneric evaluate-node (node context))
(defgeneric describe-entity (node context))
(defgeneric collect-choices (node context))
(defgeneric execute-effect (node context))
(defgeneric evaluate-condition (node context))
(defgeneric validate-node (node game report))
(defgeneric compile-node-to-js (node compiler))
(defgeneric compile-effect-to-js (node compiler))
(defgeneric compile-condition-to-js (node compiler))
```

The console runtime, validator, and JavaScript compiler should all consume the
same story AST. If a behavior cannot be validated or compiled because it is
opaque Lisp, it does not belong in authored Dunge story data.

## Save And Load

Save files should serialize runtime state, not executable story code. The
minimum save payload is:

```lisp
(:current-room "cupboard"
 :return-stack ("kitchen")
 :globals ((:recipe . t))
 :taken-choices (:take-recipe))
```

Entity-local state can be added when save/load is implemented. The format can
start as s-expressions and later move to JSON because the data model does not
depend on Lisp execution.

## Validator

Validation should be a separate pass over the AST after game construction.
It should catch authoring errors before play:

- missing `goto` and `gosub` room targets when statically known;
- malformed conditions and effects;
- unknown state scopes or operators;
- once-only choices without stable IDs;
- duplicate room names and duplicate scene IDs;
- unresolved entity refs.

Dynamic values that cannot be statically resolved should be reported as such
rather than silently accepted as validated.

## Implementation Order

1. Add state primitive AST nodes and condition evaluation for global state.
2. Add `sequence` for choice effects/control.
3. Add `branch`, with `shown-when` and `shown-unless` as sugar.
4. Add `option :when`, `option :once`, and stable choice IDs.
5. Add the validator pass.
6. Add save/load for current room, return stack, globals, taken choices, and
   eventually entity-local state.
7. Add the JavaScript compiler pass once the runtime language surface has
   settled.

## Scope Cuts

Dunge will not have inline links. Choices are enough.

Dunge will not embed arbitrary Lisp in story data. Authoring helpers must
produce AST nodes.

Dunge will not copy the full Twine or Ink surface area. The bar is stateful,
validatable, saveable choice-based IF with a small set of flexible primitives.
