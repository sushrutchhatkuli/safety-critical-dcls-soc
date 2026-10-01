---
title: "ISO 26262 ASIL-D Deep Dive: Safety Integrity Levels, SPFM, LFM, and FTTI"
tags:
  - iso26262
  - asil-d
  - spfm
  - lfm
  - ftti
  - pmhf
  - functional-safety
date_created: 2026-10-01
status: "Active / Production"
---

# ISO 26262 ASIL-D Deep Dive

> [!NOTE] **Standard Reference**
> **ISO 26262: Road vehicles — Functional safety (Parts 1–12)**. Part 5 specifically governs hardware-level design, quantitative safety metrics, and diagnostic mechanisms.

---

## 1. What is ASIL? (Automotive Safety Integrity Level)

ISO 26262 classifies hazard risk through three distinct parameters:
1. **Severity (S)**: S0 (No injuries) to S3 (Life-threatening / fatal injuries).
2. **Exposure (E)**: E0 (Extremely unlikely) to E4 (High probability $> 10\%$ of driving time).
3. **Controllability (C)**: C0 (Controllable in general) to C3 (Difficult or impossible to control).

$$\text{ASIL} = f(\text{Severity}, \text{Exposure}, \text{Controllability})$$

```
                   ┌─────────────┬───────────────────────────────────────────┐
                   │             │               Exposure (E)                │
                   │ Severity (S)├───────────┬───────────┬───────────┬───────┤
                   │             │    E1     │    E2     │    E3     │  E4   │
                   ├─────────────┼───────────┼───────────┼───────────┼───────┤
                   │ S3          │    QM     │  ASIL A   │  ASIL B   │ASIL D │
                   │ (Fatal)     │           │           │           │       │
                   └─────────────┴───────────┴───────────┴───────────┴───────┘
```
**ASIL-D** is the highest and most rigorous safety classification in automotive engineering. It is mandated for steering, braking, battery disconnection, and automated driving actuators.

---

## 2. Quantitative Hardware Architectural Metrics

ISO 26262 Part 5 mandates three strict mathematical targets for ASIL-D compliance:

| Metric | Full Name | Target for ASIL-D | Mathematical Formulation |
| :--- | :--- | :--- | :--- |
| **SPFM** | **Single Point Fault Metric** | **$> 99.0\%$** | $$\text{SPFM} = 1 - \frac{\sum (\lambda_{SPF} + \lambda_{RF})}{\sum \lambda} = \frac{\sum \lambda_{MPF\_lat} + \sum \lambda_{safe} + \sum \lambda_{det\_SPF}}{\sum \lambda}$$ |
| **LFM** | **Latent Fault Metric** | **$> 90.0\%$** | $$\text{LFM} = 1 - \frac{\sum \lambda_{MPF\_lat}}{\sum (\lambda - \lambda_{SPF} - \lambda_{RF})}$$ |
| **PMHF** | **Probabilistic Metric for Random Hardware Failures** | **$< 10\text{ FIT}$** ($10^{-8} / \text{hour}$) | FIT = Failures in Time ($1\text{ failure per } 10^9\text{ device hours}$) |

### Where:
- $\lambda$: Total failure rate of the component.
- $\lambda_{SPF}$: Single Point Failure rate (fault leads directly to safety goal violation with no safety mechanism).
- $\lambda_{RF}$: Residual Fault rate (fault leads directly to safety goal violation, escaping detection by safety mechanisms).
- $\lambda_{MPF\_lat}$: Multiple Point Faults that remain latent / dormant.
- $\lambda_{safe}$: Safe faults that have no potential to violate the safety goal.

---

## 3. The Fault Tolerant Time Interval (FTTI) Budget

The **Fault Tolerant Time Interval (FTTI)** is the maximum duration between a hardware fault occurring and the system transitioning into a safe state before a hazardous event manifests in the physical world.

```
 Fault Injected                                                     Hazardous Event
 (Cosmic Neutron)                                                  (Vehicle Crash)
       │                                                                  │
       ▼                                                                  ▼
───────┼─────────────────────────── FTTI ─────────────────────────────────┼─────────► Time
       │◄── Fault Detection Time ─►│◄── Fault Reaction Time ──►│◄─ Margin ─►│
       │         (FDT)             │          (FRT)           │          │
       └───────────────────────────┴──────────────────────────┴──────────┘
                                   │                          │
                             DCLS Comparator            Actuator Motor
                            Fires Disconnect            Clamped to Safe
```

### Automotive FTTI Comparison:
- **Autonomous Emergency Braking (AEB)**: $\text{FTTI} \approx 20\text{ ms} - 50\text{ ms}$
- **Steer-by-Wire Motor Drive**: $\text{FTTI} \approx 10\text{ ms} - 20\text{ ms}$
- **In-Silicon Safety Gate (This DCLS SoC)**:
  - Core Clock: $f_{clk} = 100\text{ MHz} \implies T_{clk} = 10\text{ ns}$
  - Fault Detection Latency: $\le 2\text{ clock cycles} = 20\text{ ns}$
  - Bus Clamp Isolation: Combinational Zero-Cycle $= 0.8\text{ ns}$
  - **Total Silicon Reaction Time**: $\approx 20.8\text{ ns}$

$$\text{Safety Margin} = \frac{\text{FTTI}_{\text{automotive}} - \text{Latency}_{\text{DCLS}}}{\text{FTTI}_{\text{automotive}}} = \frac{10\text{ ms} - 20.8\text{ ns}}{10\text{ ms}} \approx 99.9998\%$$

By isolating the fault within **$20.8\text{ nanoseconds}$**, the DCLS SoC consumes virtually zero percentage of the vehicle's $10\text{ ms}$ mechanical safety budget.

---

## 4. Diagnostic Coverage (DC)

Diagnostic Coverage quantifies the efficacy of the safety mechanism:
$$DC = \frac{\sum \lambda_{\text{detected}}}{\sum \lambda_{\text{total}}} \times 100\%$$

In our Dual-Core Lockstep system:
- **Bus Address Lines ($32\text{ bits}$)**: $DC = 100\%$
- **Bus Data Write Lines ($32\text{ bits}$)**: $DC = 100\%$
- **Write Strobes ($4\text{ bits}$)**: $DC = 100\%$
- **Read/Write Enables ($2\text{ bits}$)**: $DC = 100\%$

Every micro-operation that can alter state outside the CPU boundary must traverse the comparator firewall, guaranteeing $DC > 99\%$, directly fulfilling the **ASIL-D SPFM criterion**.

Next: Read [[02_Common_Cause_Failures_and_Temporal_Diversity | Common Cause Failures & Temporal Diversity Proof]] to understand how dual-core redundancy is protected against simultaneous common-mode destruction.
