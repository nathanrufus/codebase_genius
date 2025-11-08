import from utils { clone_repo, walk_tree, parse_files_with_ccg, write_output }
import from byllm.llm { Model }
include utils;

# Global LLM
glob llm = Model(model_name="gemini/gemini-2.0-flash");

node Memory {}

node Session {
    has history: list = [];
    has created_at: str = get_current_datetime();

    def add_history(entry: str) {
        self.history = self.history + [entry];
    }
    def get_history -> str {
        return "\n".join(self.history[-12:]);
    }
}

node RepoMapper {
    has repo_url: str = "";
    has local_path: str = "";

    def clone_and_map(url: str) -> str {
        path = clone_repo(url);
        self.repo_url = url;
        self.local_path = path;
        return path;
    }

    def build_file_tree() -> list {
            return walk_tree(self.local_path);
        }

    def summarize_readme(readme_text: str) -> str by llm();
}

sem RepoMapper.summarize_readme = """
You are a concise README summarizer. Produce:
- A 2-4 sentence high-level overview (one paragraph).
- A short bullet list: Purpose, Key files/entrypoints, Quick start hint.
- No filler. Keep it under 120 words.
Example input: \"This project is a Flask app...\" 
Example output:
Overview: A lightweight Flask app for X...
Bullets:
- Purpose: ...
- Main entry: app.py
- Quick start: python -m ...
""";

node CodeAnalyzer {
        def analyze_and_build_ccg(file_list: list) -> dict[str, any] {
            return parse_files_with_ccg(file_list);
        }

      def refine_ccg(ccg_raw: dict[str, dict[str, list[str]]]) -> dict[str, dict[str, list[str]]] by llm();

}


sem CodeAnalyzer.refine_ccg = """
You are an assistant that takes a raw code-context graph (CCG) and enriches it for documentation.
Input: a JSON-like structure containing modules, functions, classes, and basic call edges.
Output: enriched structure with:
- For each function: short purpose sentence (1-2 lines), parameters summary, returns summary if inferable.
- For each class: short purpose sentence and key methods.
- A 'hotspots' list: functions/classes that appear most connected (high degree).
Provide output only as JSON-parsable structure.
Few-shot examples:
Input: {\"module\":\"m.py\",\"functions\": [{\"name\":\"train\",\"calls\":[\"load_data\"]}], \"classes\": []}
Output: { ... enriched fields ... }
""";

node DocGenie {
    def generate_markdown(repo_meta: dict[str, str], ccg: dict[str, dict[str, list[str]]], readme_summary: str) -> str by llm();
    def save_markdown(md: str, repo_name: str) {
        write_output(repo_name, md);
    }
}

sem DocGenie.generate_markdown = """
You are DocGenie - convert structured repository metadata and Code Context Graph (CCG) into a clear Markdown document.
Include:
1. Title & brief readme_summary (one paragraph).
2. Installation (if README provides hints).
3. Project layout (a nested file tree summary).
4. API reference: for each module, list functions and classes with the enriched short descriptions from the CCG.
5. Diagrams: produce a Mermaid flowchart or class diagram showing the top 10 hotspots and their relationships. Provide the mermaid code block.
6. Usage examples or entrypoint info (from readme or inferred).
7. References: list files where key functions/classes are defined.
Be concise, structured, and use headings, bullets, and code blocks. Provide links to source file paths using relative paths.
Example snippet:
# Project Title
Overview: ...
## Installation
...
## API Reference
### module.py
- `train(data)` — Trains the model. Calls: load_data, preprocess.
...
## Diagram (Mermaid)
\`\`\`mermaid
graph LR
  Train --> LoadData
\`\`\`
""";

walker codegenius {
    has utterance: str = "";
    has session_id: str = "";

    obj __specs__ { static has auth: bool = False; }

    can run with `root entry {
        memory_list = [root --> (`?Memory)];
        if not memory_list {
            memory_list = root ++> Memory();
        }
        memory = memory_list[0];

        if not self.session_id {
            session_list = memory ++> Session();
            self.session = session_list[0];
        } else {
            self.session = &(self.session_id);
        }

        url = self.utterance;
        self.session.add_history("user: " + url);

        # --- Clone repository
        repo_mapper = (root ++> RepoMapper())[0];
        local_path = repo_mapper.clone_and_map(url);
        self.session.add_history("cloned: " + local_path);

        # --- Build file tree
        file_tree = repo_mapper.build_file_tree();
        self.session.add_history("mapped_files_count: " + str(len(file_tree)));

        # --- Find README
        readme_text = "";
        for f in file_tree {
            if f.get("name", "").lower().startswith("readme") && f.get("name","").lower().endswith(".md") {
                readme_text = f.get("content", "");
                break;
            }
        }

        readme_summary = "";
        if readme_text != "" {
            readme_summary = repo_mapper.summarize_readme(readme_text);
            self.session.add_history("readme_summarized");
        }

        # --- Analyze code with CodeAnalyzer (Python + tree-sitter/AST)
        analyzer = (root ++> CodeAnalyzer())[0];
        analysis = analyzer.analyze_and_build_ccg(file_tree);
        refined_ccg = analyzer.refine_ccg(analysis);
        self.session.add_history("ccg_built");

        # --- Generate docs
        docgen = (root ++> DocGenie())[0];
        md = docgen.generate_markdown({"url": url, "path": local_path}, refined_ccg, readme_summary);
        docgen.save_markdown(md, jid(root));
        self.session.add_history("documentation_generated");

        report {
            "session_id": jid(self.session),
            "repo_path": local_path,
            "doc_path": "outputs/" + jid(root) + "/docs.md",
            "summary": readme_summary
        };
    }
}

import from datetime { datetime }

def get_current_datetime() -> str {
    return str(datetime.now());
}
