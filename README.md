# Codebase Genius — Starter Implementation (with Code Analyzer improvements)

Folder: `agentic_codebase_genius/`

## Summary
This project is a starter scaffold for the Codebase Genius assignment. It includes:
- Jac orchestrator and nodes (main.jac, repo_mapper.jac, code_analyzer.jac, doc_genie.jac)
- Python helpers (utils.py) that clone repositories, walk files, and parse Python sources into a lightweight Code Context Graph (CCG).
- LLM prompts ("sem" blocks) with few-shot guidance to improve summaries and documentation generation.

## Quick Start
1. Create and activate a virtual environment:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
jac serve main.jac
sreamlit run app.py