# Evaluating a RAG system: how do you know it is better?

**In one line:** do not argue that RAG is better, measure it: check what code can check, ask a judge about what code cannot, compare against honest baselines, and say where the measurement is weak.

## Three kinds of evidence, from cheapest to softest

| Kind | Example here | Strength | Weakness |
|---|---|---|---|
| Checks in code | Every `[E3]` points at a real post; every quote is word for word | Free, exact, repeatable | Says nothing about meaning: a sentence can cite E3 and misread it |
| A judge model with a narrow job | "Does this sentence follow from only the posts it cites?" | Reads meaning; can be audited sentence by sentence | It is a model: it can be wrong or kind |
| A blind comparison | Three reports shuffled and unlabelled, scored 1-5 on four things | Compares arms directly | Coarse; judges tend to like long, fluent text |

Use all three. They fail in different ways, so agreement between them means something.

## Baselines: what should RAG beat?

- **No context** (just ask the LLM) shows whether the forum data matters at all. Expect it to lose on facts and win on nothing but cost.
- **Paste everything** is the honest rival when the data fits in the model's context. A week here is about 50,000 tokens, so pasting works. RAG has to justify itself on cost, speed and focus, not only quality. If the week were 50 times bigger, pasting would stop being an option and the comparison would change. Say that out loud when you present the result.

## Backtesting a forecast

A prediction is only worth something if it can be scored later, so:

1. Write the report as if it were an earlier date (use only data from before it).
2. Wait for the future to arrive (here: use a week that is already over).
3. Score each prediction against what happened.

**Leakage** is the way this goes wrong: a signal that quietly uses data from after the date makes the forecast look brilliant. The defence is structural (every query is bounded by the report's week) and tested (a spec plants a post in the next week and checks it never reaches the prompt).

**Calibration** asks whether "high confidence" predictions come true more often than "low" ones. If not, the stated confidence is decoration.

## LLM-as-judge: use it carefully

- Give it one narrow question and only the evidence needed to answer it.
- Require it to point at the evidence it used, and check that the pointers are real (in code).
- Hide which arm wrote what (blind), and shuffle the order with a fixed seed.
- Let a different model judge if you can (a model can prefer its own style).
- Report it as "judged by a model", never as ground truth.

## Questions to ask yourself

1. Why is "RAG got a higher score" not enough to conclude RAG is better? (What else changed? How many weeks? Who judged?)
2. If the week were ten times bigger, which arm would you drop and why?
3. What would a backtest look like if the forum had only two weeks of history?
