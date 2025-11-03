node Repository {
    has url: str;
    has name: str;
    has local_path: str;
    has status: str;  # "cloning", "analyzing", "complete", "error"
}

node File {
    has path: str;
    has name: str;
    has content: str;
    has language: str;  # "python", "jac", "markdown", etc.
    has is_entry_point: bool = false;
}

node CodeElement {
    has name: str;
    has element_type: str;  # "function", "class", "module"
    has signature: str;
    has docstring: str;
}

edge Contains{}
edge Calls {}
edge Inherits {}
edge Imports {}

node AnalysisSession {
    has session_id: str;
    has github_url: str;
    has created_at: datetime;
    has status: str;
}
