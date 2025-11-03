node DocGenie {
    # can generate_overview;
    # can generate_api_reference;
    # can create_diagrams;
    # can assemble_documentation;
    
    def generate_overview(readme_summary: str, file_tree: list) -> str by llm();
    
    def generate_api_reference(code_elements: list) -> str by llm();
    
    def create_relationship_diagram(relationships: list) -> str by llm();
    
    def assemble_final_doc(sections: dict) -> str by llm();
}

walker generate_docs {
    has readme_summary: str;
    has file_tree: list;
    has code_elements: list;
     obj __specs__ {
        static has auth: bool = False;
        static has api: bool = True;
        static has api_method: str = "POST";
    }
    def final_doc {
        doc_genie = here spawn DocGenie();
        
        overview = doc_genie.generate_overview(readme_summary, file_tree);
        api_reference = doc_genie.generate_api_reference(code_elements);
        diagrams= doc_genie.create_relationship_diagram(code_elements);
        
        final_doc= doc_genie.assemble_final_doc({
            "overview": overview,
            "api_reference": api_reference,
            "diagrams": diagrams
        });
        
        report final_doc;
    }
}
