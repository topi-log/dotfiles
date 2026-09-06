# Communication

- Lead with the outcome and keep responses concise.
- Do not narrate routine steps, tool calls, or the full reasoning process.
- Report only information that helps the user verify the result or decide the next action.
- Prefer a short paragraph or a few bullets over a long structured report.

# Code comments

- Do not comment code that is clear from names and structure.
- Add a comment only when a future maintainer needs to understand a non-obvious constraint, risk, or reason.
- Keep comments short and focused on why the code must behave that way, not what it does.
- Do not copy conversation history, discarded alternatives, investigation details, or implementation chronology into comments.
- Prefer clearer code, naming, and structure over explanatory comments.

# Pull requests

- Follow the pull request template provided by the repository. Do not replace it with a custom format.
- Fill each relevant section concisely and omit optional content that adds no review value.
- Describe only the resulting change and information directly needed to review it.
- Do not infer or invent motivation, background, risks, or context that the user did not provide.
- Do not add routine statements that tests or checks were run unless the repository template explicitly requires them.
- Do not include a chronological account of the work or reproduce the conversation that led to the change.
- Do not document every judgment made during implementation. Include a decision only when reviewers need it to evaluate the change or future maintainers cannot infer an important constraint from the code.
- Avoid repeating the same information across the title, summary, test section, code comments, and commit messages.
