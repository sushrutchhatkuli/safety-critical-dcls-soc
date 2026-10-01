---
title: "Common Cause Failures (CCF) & Mathematical Proof of Temporal Diversity (The 2-Cycle Stagger)"
tags:
  - ccf
  - temporal-diversity
  - lockstep
  - beta-factor
  - mathematical-proof
  - iso26262
date_created: 2026-10-01
status: "Active / Production"
---

# Common Cause Failures & The 2-Cycle Temporal Diversity Stagger

> [!IMPORTANT] **The Flaw of Naive Dual Redundancy**
> If you instantiate two identical cores side-by-side on the same clock edge, a localized electromagnetic pulse (EMP), voltage droop, or thermal surge can flip the exact same bit in both cores simultaneously. A standard comparator will report that both cores agree—silently passing lethal corrupted data to external actuators.

---

## 1. What is a Common Cause Failure (CCF)?

A **Common Cause Failure (CCF)** occurs when multiple distinct channels or redundant units fail simultaneously due to a single shared root cause:
- **Global Clock Jitter / Glitch**: A transient clock pulse causes both cores to skip an execution cycle simultaneously.
- **Power Distribution Network (PDN) Voltage Droop**: High-current switching drops $V_{DD}$ below the minimum retention voltage $V_{ret}$, corrupting register files in both cores in parallel.
- **Electromagnetic Interference (EMI)**: Inductive ignition or high-frequency motor switching broadcasting an EM wave across the die.

### The $\beta$-Factor Reliability Model
In safety engineering (IEC 61508 / ISO 26262), the failure rate $\lambda$ of a redundant 1oo2 (1-out-of-2) system is divided into independent failures ($\lambda_i$) and common-cause failures ($\lambda_{cc}$):

$$\lambda_{\text{total}} = (1 - \beta)\lambda + \beta\lambda$$

Where:
- $\beta$ is the Common Cause Coupling Factor ($0 \le \beta \le 1$).
- If $\beta = 0$, both channels are completely independent.
- If $\beta > 0$, redundancy degrades. Even if each core has an independent failure rate of $10^{-6}\text{ failures/hr}$, a $\beta = 0.05$ ($5\%$) produces a CCF rate of:

$$\lambda_{CCF} = 0.05 \times 10^{-6} = 50\text{ FIT}$$

This immediately violates the ASIL-D target ($< 10\text{ FIT}$). **Eliminating $\beta$ is mandatory**.

---

## 2. The Solution: Temporal Diversity ($\Delta t = 2\text{ Cycles}$)

To break the temporal symmetry between Core Master ($C_M$) and Core Shadow ($C_S$), we introduce a deterministic time offset:

$$\Delta t = 2\text{ clock cycles}$$

```
 Clock Cycle:        T0          T1          T2          T3          T4
                 ┌───────────┬───────────┬───────────┬───────────┬───────────┐
 Core Master:    │  Instr K  │ Instr K+1 │ Instr K+2 │ Instr K+3 │ Instr K+4 │
                 └───────────┴───────────┴───────────┴───────────┴───────────┘
                                         ▲
                                         │  Δt = 2 cycles delay
                                         ▼
 Core Shadow:    │ Instr K-2 │ Instr K-1 │  Instr K  │ Instr K+1 │ Instr K+2 │
                 └───────────┴───────────┴───────────┴───────────┴───────────┘
```

### The Architectural Equations:
1. **Shadow Input Shift Register**:
   $$\text{Inputs}_{\text{shadow}}(t) = \text{Inputs}_{\text{master}}(t - 2)$$
2. **Master Output Shift Register**:
   $$\text{Outputs}_{\text{master\_delayed}}(t) = \text{Outputs}_{\text{master}}(t - 2)$$
3. **Comparator Evaluation**:
   $$\text{Fault}(t) = \left(\text{Outputs}_{\text{master\_delayed}}(t) \ne \text{Outputs}_{\text{shadow}}(t)\right)$$

---

## 3. Mathematical Proof of CCF Immunity

### Scenario A: Transient Disturbance Hitting at Time $t_0$
Let a physical event (EMP spike or voltage droop) impact the die at clock cycle $t_0$:

1. At time $t_0$:
   - Core Master is executing Instruction $K$. The glitch corrupts an internal state register:
     $$S_M(t_0) = S_K \oplus \delta_M$$
   - Core Shadow is executing Instruction $K-2$. The same glitch corrupts its state:
     $$S_S(t_0) = S_{K-2} \oplus \delta_S$$

2. Core Master's corrupted result from Instruction $K$ exits its pipeline and enters the 2-cycle master output delay shift register. It will reach the comparator at time $t_0 + 2$:
   $$\text{Outputs}_{\text{master\_delayed}}(t_0 + 2) = f(S_K \oplus \delta_M)$$

3. What is Core Shadow doing at time $t_0 + 2$?
   - Core Shadow is now executing Instruction $K$.
   - **Crucially, the transient glitch hit at time $t_0$ and has already decayed by $t_0 + 2$!**
   - Core Shadow executes Instruction $K$ with the uncorrupted input stream that was delayed in the input shift registers:
     $$\text{Outputs}_{\text{shadow}}(t_0 + 2) = f(S_K)$$

4. The Comparator evaluates at clock cycle $t_0 + 2$:
   $$\text{Fault}(t_0 + 2) = \left[ f(S_K \oplus \delta_M) \ne f(S_K) \right] \equiv \mathbf{1\ (TRUE)}$$

$$\therefore \text{Detection Probability } P(\text{Detect}) = 100\%$$

> [!TIP] **Why Exactly 2 Cycles? Why Not 1 Cycle?**
> A single-cycle stagger ($\Delta t = 1$) is susceptible to multi-cycle inductive ringing on the power rails, where an undershoot at $T_0$ is followed by a rebound overshoot at $T_1$. A 2-cycle stagger ($\Delta t = 2$, or $20\text{ ns}$ at $100\text{ MHz}$) provides sufficient temporal separation for high-frequency RLC ringing to attenuate below the transistor noise margin.

Next: Review the concrete SystemVerilog module implementation in [[01_DCLS_Core_Wrapper_Architecture | DCLS Core Wrapper Architecture]].
