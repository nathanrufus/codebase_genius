node RepoMapper {
    # can clone_repository;
    # can generate_file_tree;
    # can summarize_readme;
    
    def clone_repository(repo_url: str) -> str {
        # Python integration for git operations
        return py.utils.clone_repo(repo_url);
    }
    
    def generate_file_tree(local_path: str) -> list by llm(
        method="ReAct",
        tools=([py.utils.list_files])
    );
    
    def summarize_readme(readme_path: str) -> str by llm();
}

walker clone_and_map {
    has repo_url:str;
    
    with entry {
        repo_mapper = here spawn  RepoMapper;
        
        # Clone repository
        local_path = repo_mapper.clone_repository(repo_url);
        
        # Generate file tree
        file_tree = repo_mapper.generate_file_tree(local_path);
        
        # Find and summarize README
        readme_summary = repo_mapper.summarize_readme(local_path + "/README.md");
        
        report {
            "local_path": local_path,
            "file_tree": file_tree,
            "readme_summary": readme_summary
        };
    }
}