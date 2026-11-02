import Mathlib

theorem solution (a b : ℕ) : a + b = b + a := by
  exact Nat.add_comm a b
