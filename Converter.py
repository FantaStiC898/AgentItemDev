import re
import json
import html
import markdown
import uuid

def extract_content(raw_content):
    """Extract thinking process, JSON content, and remaining markdown from raw input"""
    # Step 1: Extract thinking process if <think> tags exist
    think_match = re.search(r'<think>([\s\S]*?)</think>', raw_content)
    thinking_process = think_match.group(1).strip() if think_match else ''
    
    # Remove thinking process from content for further processing
    content_without_thinking = raw_content
    if think_match:
        content_without_thinking = raw_content.replace(think_match.group(0), '')
    
    # Step 2: Try to identify JSON content
    json_obj = {}
    markdown_content = content_without_thinking.strip()
    
    # Try different JSON extraction strategies
    json_patterns = [
        # Complete JSON object pattern
        r'(\{[\s\S]*\})',
        # JSON in code blocks
        r'```(?:json)?\s*\n([\s\S]*?)\n```',
        # JSON with backticks but no language specifier
        r'`([\s\S]*?)`'
    ]
    
    for pattern in json_patterns:
        matches = re.findall(pattern, content_without_thinking)
        for match in matches:
            try:
                # Try to parse as JSON
                potential_json = json.loads(match)
                if isinstance(potential_json, dict) and len(potential_json) > 0:
                    json_obj = potential_json
                    # Remove the JSON part from markdown content
                    markdown_content = content_without_thinking.replace(match, '').strip()
                    break
            except json.JSONDecodeError:
                continue
        if json_obj:  # If JSON found, stop trying other patterns
            break
    
    # Step 3: If no JSON found in patterns, try the entire content
    if not json_obj:
        try:
            if content_without_thinking.strip().startswith('{') and content_without_thinking.strip().endswith('}'):
                json_obj = json.loads(content_without_thinking)
                markdown_content = ''  # If entire content is JSON, no markdown remains
        except json.JSONDecodeError:
            # Not JSON, treat as markdown
            pass
    
    # If still no JSON found, check if content is a quoted JSON string
    if not json_obj and content_without_thinking.strip().startswith('"') and content_without_thinking.strip().endswith('"'):
        try:
            unquoted_content = json.loads(content_without_thinking)
            if isinstance(unquoted_content, str) and unquoted_content.strip().startswith('{') and unquoted_content.strip().endswith('}'):
                try:
                    json_obj = json.loads(unquoted_content)
                    markdown_content = ''
                except json.JSONDecodeError:
                    pass
        except json.JSONDecodeError:
            pass
    
    # Step 4: Clean up markdown content
    # Remove code blocks that might contain JSON
    markdown_content = re.sub(r'```(?:json)?\s*\n[\s\S]*?\n```', '', markdown_content)
    # Remove backtick blocks
    markdown_content = re.sub(r'`[\s\S]*?`', '', markdown_content)
    # Clean up any remaining JSON-like structures
    markdown_content = re.sub(r'\{[\s\S]*\}', '', markdown_content)
    
    # Final cleanup
    markdown_content = markdown_content.strip()
    
    # If no specific markdown content found but we have thinking process, use that
    if not markdown_content and not json_obj and thinking_process:
        markdown_content = thinking_process
        thinking_process = ''
    
    return thinking_process, json_obj, markdown_content

def process_json_in_markdown(md_content):
    """Process JSON content in markdown"""
    # Find JSON code blocks
    json_pattern = r"```json\s*\n([\s\S]*?)\n```"
    
    # Replace JSON code blocks with special markers
    def replace_json(match):
        return "JSON_BLOCK_MARKER" + match.group(1) + "JSON_BLOCK_MARKER_END"
    
    md_with_markers = re.sub(json_pattern, replace_json, md_content)
    return md_with_markers

def restore_json_blocks(html_content):
    """Restore JSON blocks in HTML content"""
    # Extract JSON content
    json_pattern = r"JSON_BLOCK_MARKER([\s\S]*?)JSON_BLOCK_MARKER_END"
    json_matches = re.findall(json_pattern, html_content)
    
    # Replace each marker with appropriate JSON viewer
    for match_content in json_matches:
        # Escape HTML special characters
        safe_content = html.escape(match_content)
        
        # Try to format JSON (if valid)
        try:
            parsed_json = json.loads(match_content)
            formatted_json = json.dumps(parsed_json, indent=2)
            safe_content = html.escape(formatted_json)
        except json.JSONDecodeError:
            # If not valid JSON, keep as is
            pass
            
        json_viewer = f'''<div class="json-viewer"><pre><code class="language-json">{safe_content}</code></pre></div>'''
        
        # Replace markers in HTML content
        marker = "JSON_BLOCK_MARKER" + match_content + "JSON_BLOCK_MARKER_END"
        html_content = html_content.replace(marker, json_viewer)
    
    return html_content

def generate_html(thinking_process, json_obj, markdown_content, unique_id=None):
    """Generate HTML content"""
    # Generate unique ID if not provided
    if unique_id is None:
        unique_id = f"json_{uuid.uuid4().hex[:8]}"
    
    # Process thinking process markdown with JSON processing
    thinking_processed = process_json_in_markdown(thinking_process) if thinking_process else ''
    markdown_processed = process_json_in_markdown(markdown_content) if markdown_content else ''
    
    # Convert to HTML
    thinking_html_raw = markdown.markdown(thinking_processed, extensions=['tables']) if thinking_processed else ''
    markdown_html_raw = markdown.markdown(markdown_processed, extensions=['tables']) if markdown_processed else ''
    
    # Restore JSON blocks
    thinking_html = restore_json_blocks(thinking_html_raw) if thinking_html_raw else ''
    markdown_html = restore_json_blocks(markdown_html_raw) if markdown_html_raw else ''
    
    json_str = json.dumps(json_obj, indent=4, ensure_ascii=False) if json_obj else '{}'
    
    has_thinking_content = bool(thinking_process.strip().replace('\n', '').replace('\t', '').replace('\r', ''))
    has_json_content = bool(json_obj)
    has_markdown_content = bool(markdown_content.strip().replace('\n', '').replace('\t', '').replace('\r', ''))
    
    # CSS styles
    css_styles = '''
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f9f9f9;
        }
        
        .container {
            display: flex;
            flex-direction: column;
            gap: 20px;
        }
        
        .think-container {
            margin-bottom: 20px;
            border-bottom: 1px solid #e0e0e0;
            padding-bottom: 15px;
        }
        
        .think-summary {
            cursor: pointer;
            color: #2196F3;
            font-weight: 500;
            display: inline-block;
            padding: 5px 10px;
            border-radius: 4px;
            background-color: #f5f5f5;
            transition: background-color 0.3s;
        }
        
        .think-summary:hover {
            background-color: #e3f2fd;
        }
        
        .think-content {
            margin-top: 10px;
            padding: 15px;
            background-color: #f9f9f9;
            border-radius: 6px;
            border-left: 4px solid #2196F3;
        }
        
        .think-content p {
            margin-bottom: 10px;
            line-height: 1.5;
        }
        
        .think-content code {
            background-color: #f0f0f0;
            padding: 2px 4px;
            border-radius: 3px;
        }
        
        .think-content pre {
            background-color: #f0f0f0;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
        }
        
        .json-viewer {
            background-color: #f8f8f8;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 10px;
            margin: 10px 0;
            max-height: 400px;
            overflow: auto;
        }
        
        .json-string { color: #008000; }
        .json-number { color: #0000ff; }
        .json-boolean { color: #b22222; }
        .json-null { color: #808080; }
        .json-key { color: #a52a2a; }
        
        pre {
            margin: 0;
            white-space: pre-wrap;
        }
        
        .markdown-body {
            line-height: 1.6;
        }
        .markdown-body h1, .markdown-body h2, .markdown-body h3 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }
        .markdown-body code {
            padding: 0.2em 0.4em;
            margin: 0;
            font-size: 85%;
            background-color: rgba(27,31,35,0.05);
            border-radius: 3px;
        }
        .markdown-body pre {
            padding: 16px;
            overflow: auto;
            font-size: 85%;
            line-height: 1.45;
            background-color: #f6f8fa;
            border-radius: 3px;
        }
        
        .markdown-section {
            margin-top: 20px;
            padding: 15px;
            background-color: #ffffff;
            border-radius: 6px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        
        .markdown-body table {
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 16px;
        }
        
        .markdown-body table th,
        .markdown-body table td {
            padding: 8px;
            border: 1px solid #ddd;
        }
        
        .markdown-body table th {
            background-color: #f2f2f2;
            font-weight: 600;
            text-align: left;
        }
        
        .markdown-body table tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        
        .markdown-body table tr:hover {
            background-color: #f5f5f5;
        }
    </style>
    '''
    
    # JavaScript for JSON formatting
    js_script = f'''
    <script>
        function highlightJSON(json) {{
            if (!json) return "";
            return json
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
                .replace(/("(\\u[a-zA-Z0-9]{{4}}|\\[^u]|[^\\"])*"(\\s*:)?|\\b(true|false|null)\\b|-?\\d+(?:\\.\\d*)?(?:[eE][+\\-]?\\d+)?)/g, function (match) {{
                    let cls = "json-number";
                    if (/^"/.test(match)) {{
                        if (/:$/.test(match)) {{
                            cls = "json-key";
                        }} else {{
                            cls = "json-string";
                        }}
                    }} else if (/true|false/.test(match)) {{
                        cls = "json-boolean";
                    }} else if (/null/.test(match)) {{
                        cls = "json-null";
                    }}
                    return '<span class="' + cls + '">' + match + '</span>';
                }});
        }}
        
        function formatJSON(jsonString) {{
            try {{
                const json = JSON.parse(jsonString);
                return JSON.stringify(json, null, 2);
            }} catch (e) {{
                return jsonString;
            }}
        }}
        
        document.addEventListener("DOMContentLoaded", function() {{
            // Process inline JSON code blocks
            const jsonBlocks = document.querySelectorAll("pre code.language-json");
            jsonBlocks.forEach(function(block) {{
                const jsonContent = block.textContent;
                const formattedJSON = formatJSON(jsonContent);
                const highlightedJSON = highlightJSON(formattedJSON);
                
                const viewer = document.createElement("div");
                viewer.className = "json-viewer";
                viewer.innerHTML = "<pre>" + highlightedJSON + "</pre>";
                
                block.parentNode.parentNode.replaceChild(viewer, block.parentNode);
            }});
            
            // Process main JSON display area - using unique ID
            if (document.getElementById('{unique_id}') && typeof {unique_id}_jsonContent !== 'undefined') {{
                const formattedJSON = formatJSON({unique_id}_jsonContent);
                document.getElementById('{unique_id}').innerHTML = highlightJSON(formattedJSON);
            }}
        }});
    </script>
    '''
    
    # Build HTML content sections
    thinking_section = ''
    if has_thinking_content:
        thinking_section = f'''
        <div class="think-container">
            <details>
                <summary class="think-summary">View Thinking Process</summary>
                <div class="think-content">
                    {thinking_html}
                </div>
            </details>
        </div>
        '''
    
    json_section = ''
    if has_json_content:
        json_section = f'''
        <div class="json-viewer">
            <pre id="{unique_id}"></pre>
        </div>
        '''
    
    markdown_section = ''
    if has_markdown_content:
        markdown_section = f'''
        <div class="markdown-section markdown-body">
            {markdown_html}
        </div>
        '''
    
    # Assemble the final HTML
    html_content = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Content Viewer</title>
    {css_styles}
</head>
<body>
    <div class="container">
        {thinking_section}
        {markdown_section}
        {json_section}
    </div>
    
    <script>
        const {unique_id}_jsonContent = `{json_str}`;
    </script>
    {js_script}
</body>
</html>
'''
    
    # Escape special characters to avoid JavaScript string issues
    escaped_json = html.escape(json_str).replace('\\', '\\\\').replace('`', '\\`').replace('$', '\\$')
    html_content = html_content.replace('{json_str}', escaped_json)
    
    return html_content

def convert_to_html(content, index=None):
    """Convert content to HTML and return HTML string"""
    try:
        # Generate unique ID based on index if provided
        unique_id = f"json_display_{index}" if index is not None else None
        
        # Extract content components
        thinking_process, json_obj, markdown_content = extract_content(content)
        
        # Generate HTML
        result = generate_html(thinking_process, json_obj, markdown_content, unique_id)
        
        return result
    except Exception as e:
        print(f"Error converting to HTML: {str(e)}")
        error_content = f"<p>Error processing content: {html.escape(str(e))}</p>"
        
        # Return a simple error page instead of an empty string
        return f"""
        <!DOCTYPE html>
        <html>
        <head><title>Error</title></head>
        <body>
            <h1>Error processing content</h1>
            {error_content}
            <pre>{html.escape(content[:500])}...</pre>
        </body>
        </html>
        """

def merge_html_content(contents):
    """Merge multiple HTML contents, removing duplicate structures"""
    merged = "<!DOCTYPE html><html><head>"
    
    # Add the head content of the first file
    first_head_end = contents[0].find("</head>")
    merged += contents[0][:first_head_end] + "</head><body>"
    
    # Add the body part of all contents
    for content in contents:
        body_start = content.find("<body>") + len("<body>")
        body_end = content.find("</body>")
        merged += content[body_start:body_end]
    
    merged += "</body></html>"
    
    # Remove duplicate scripts and styles
    merged = re.sub(r"(<script>.*?</script>){2,}", "<script>\\1</script>", merged, flags=re.DOTALL)
    merged = re.sub(r"(<style>.*?</style>){2,}", "<style>\\1</style>", merged, flags=re.DOTALL)
    
    return merged

def batch_convert_to_html(contents):
    """Convert multiple content items to HTML and merge them"""
    html_contents = []
    for i, content in enumerate(contents):
        html_content = convert_to_html(content, i)
        html_contents.append(html_content)
    
    if html_contents:
        return merge_html_content(html_contents)
    else:
        return "<html><body><p>No content to display</p></body></html>"
