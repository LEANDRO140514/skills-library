# MCP Server Evaluation Guide

## Purpose

Evaluations test whether LLMs can effectively use your MCP server to answer realistic, complex questions. The measure of quality is NOT how well the server implements tools, but how well those implementations enable LLMs to answer difficult questions.

---

## Requirements

Create **10 evaluation questions** that are:

- **Read-only**: Only non-destructive operations required
- **Independent**: Each question stands alone (not dependent on others)
- **Complex**: Requiring multiple tool calls and deep exploration
- **Realistic**: Based on real use cases humans would care about
- **Verifiable**: Single, clear answer verifiable by string comparison
- **Stable**: Answer won't change over time

Prefer human-readable answers (names, dates, URLs) over opaque identifiers (IDs, hashes).

---

## Process

1. **Tool Inspection** — List available tools and understand their capabilities
2. **Content Exploration** — Use READ-ONLY operations to explore available data
3. **Develop Understanding** — Iterate through the data to find interesting patterns
4. **Question Generation** — Create 10 complex, realistic questions
5. **Answer Verification** — Solve each question yourself to verify the answer

---

## Output Format

```xml
<evaluation>
  <qa_pair>
    <question>Find discussions about AI model launches with animal codenames. One model needed a specific safety designation that uses the format ASL-X. What number X was being determined for the model named after a spotted wild cat?</question>
    <answer>3</answer>
  </qa_pair>
  <qa_pair>
    <question>Which user has the most assigned open issues across all projects?</question>
    <answer>Jane Smith</answer>
  </qa_pair>
  <!-- 8 more qa_pairs... -->
</evaluation>
```

---

## Good vs. Bad Questions

### Good
- Requires multiple tool calls to answer
- Tests real workflow (e.g., "find the PR that introduced bug X")
- Answer is specific and verifiable ("Jane Smith", "42", "2024-01-15")

### Bad
- Answerable with a single tool call
- Keyword-matchable without exploring data
- Answer is ambiguous or changes over time
- Requires destructive/write operations

---

## Running Evaluations

Evaluations can be run with a Python script supporting three transport types:

```bash
# stdio
python run_eval.py --transport stdio --server "python server.py" --eval eval.xml

# HTTP
python run_eval.py --transport http --url http://localhost:3000/mcp --eval eval.xml

# SSE (legacy)
python run_eval.py --transport sse --url http://localhost:3000/sse --eval eval.xml
```

Output includes accuracy metrics and per-task analysis showing which questions the LLM answered correctly.
