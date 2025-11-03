node CodeAnalyzer {
    # can parse_file;
    # can extract_functions;
    # can extract_classes;
    # can build_relationships;
    
    def parse_file(file_path: str) -> dict {
        return py.utils.parse_with_treesitter(file_path);
    }
    
    def identify_entry_points(file_tree: list) -> list by llm();
    
    def analyze_code_structure(file_content: str) -> dict by llm();
}

walker analyze_codebase {
    has local_path :str;
    has file_tree: list;
     obj __specs__ {
        static has auth: bool = False;
        static has api: bool = True;
        static has api_method: str = "POST";
    }
    def code_elements {
        analyzer = here spawn CodeAnalyzer();
        
        # Identify entry points
        entry_points = analyzer.identify_entry_points(file_tree);
        
        # Build Code Context Graph
        for file_info in file_tree {
            if (file_info.path in entry_points) {
                file_node = here spawn File(
                    path=file_info.path,
                    name=file_info.name,
                    language=file_info.language
                );
                
                # Parse and analyze
                analysis = analyzer.parse_file(file_info.full_path);
                
                # Create code elements and relationships
                for element in analysis.elements {
                    element_node = file_node spawn  CodeElement(
                        name=element.name,
                        element_type=element.type,
                        signature=element.signature
                    );
                }
            }
        }
        
        report "Code Context Graph built with " + std.length([here --> (`?CodeElement)]) + " elements";
    }
}