# main.jac
import from agents.supervisor { Supervisor, codebase_genius }
import from agents.repo_mapper { RepoMapper, clone_and_map }
import from agents.code_analyzer { CodeAnalyzer, analyze_codebase }
import from agents.doc_genie { DocGenie, generate_docs }
import from byllm.llm { Model }

# Global LLM configuration
glob llm = Model(model_name="gemini/gemini-2.0-flash");

# Root graph structure
node Root {}

node AnalysisSession {
    has session_id: str;
    has github_url: str;
    has created_at: datetime;
    has status: str;
}

# API entry point
walker initiate_analysis {
    has github_url: str;

    obj __specs__ {
        static has auth: bool = False;
        static has api: bool = True;
        static has api_method: str = "POST";
        static has api_path: str = "/walker/initiate_analysis";
    }

    def start {
        # Create analysis session
        session = here spawn AnalysisSession(
            github_url=self.github_url,
            session_id=std.uuid4(),
            created_at=std.now(),
            status="started"
        );

        # Start main workflow
        here spawn codebase_genius(
            github_url=self.github_url,
            session_id=session.session_id
        );

        report {
            "session_id": session.session_id,
            "status": "analysis_started",
            "message": "Documentation generation initiated"
        };
    }
}