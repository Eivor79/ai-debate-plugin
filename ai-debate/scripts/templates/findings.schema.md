# Review findings schema

Structured findings make adversarial review high-signal and machine-aggregatable.
Each round that raises or carries issues uses a `## Findings` section; one block per issue.

```
## Findings
- id: F1
  severity: high | medium | low
  confidence: high | medium | low
  claim: <one falsifiable sentence>
  evidence: <file:line, data, quote, or repro — no hand-waving>
  refutable_by: <the specific observation that would disprove this claim>
```

## Round roles

- **DESIGNER** (`001_*_design.md`): write the design, then a `## Self-critique` that pre-empts the attacker with the strongest objections to your own design.
- **ATTACKER** (`*_attack_*`): strongest concrete refutations. Priority correctness > feasibility > measurement validity > scope. No softening.
- **REBUTTER** (`*_rebuttal_*`): per finding, assign a **verdict**:
  - `CONFIRMED` — real; concede and state the fix/scope change.
  - `PLAUSIBLE` — real under a realistic named condition; keep with caveats.
  - `REFUTED` — provably wrong; must cite the concrete code/data counter.
- **JUDGE** (`decision.md`): adopt only surviving findings (CONFIRMED + well-evidenced PLAUSIBLE), drop REFUTED. Record adopted ids, decision (adopt/reject/revise + scope), rationale, residual risks, next step.

A finding is **adopted** only after it survives the rebuttal verdict. This adversarial-verification
step is what keeps plausible-but-wrong findings out of the final decision.
