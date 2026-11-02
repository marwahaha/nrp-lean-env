import Mathlib

/-- A tiny Mathlib-dependent example in the shape of a Prove2me solution file. -/
theorem solution (a b : ℕ) : a + b = b + a := by
  exact Nat.add_comm a b
