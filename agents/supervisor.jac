# agents/supervisor.jac
node Supervisor {
    def validate_github_url(url: str) -> bool by llm();
    def plan_analysis(file_tree: list, readme_summary: str) -> list by llm();
}

walker codebase_genius {
    has github_url: str;
    has session_id: str;
    
    obj __specs__ {
        static has auth: bool = False;
        static has api: bool = True;
        static has api_method: str = "POST";
    }
    
    can start with `root entry {
        # Find or create Supervisor node
        supervisors = [here --> (`?Supervisor)];
        if not supervisors {
            supervisor_node = here spawn Supervisor();
        } else {
            supervisor_node = supervisors[0];
        }
        
        # Move to supervisor node
        visit  supervisor_node;
    }
    
    can process with Supervisor entry {
        # Validate URL first
        url_valid = here.validate_github_url(visitor.github_url);
        if not url_valid {
            report {"error": "Invalid GitHub URL"};
            disengage;
        }
        
        # Step 1: Repository Mapping
        mapper = here spawn clone_and_map(repo_url=visitor.github_url);
        
        # Step 2: Code Analysis  
        analyzer = here spawn analyze_codebase(
            local_path=mapper.local_path,
            file_tree=mapper.file_tree
        );
        
        # Step 3: Documentation Generation
        docs = here spawn generate_docs(
            readme_summary=mapper.readme_summary,
            file_tree=mapper.file_tree,
            code_elements=analyzer.code_elements
        );
        
        report {
            "session_id": visitor.session_id,
            "documentation": docs.final_doc,
            "status": "complete"
        };
    }
}