Refactor the specified file using semantic functions and clean organization.

File to refactor: $ARGUMENTS (if empty, use current file: $FILE)

Apply these refactoring principles:

## Structure
- Organize code into sections with comment headers: `# === Constants ===`, `# === Models ===`, `# === Output ===`, `# === Context ===`, `# === API ===`, `# === CLI ===`, `# === Main ===`
- Only include sections that are relevant to the file

## Constants
- Extract magic values into named constants at the top (colors, exit codes, URLs, etc.)
- Group related constants together
- When possible, inline comment on magic numbers

## Functions
- Extract semantic helper functions with clear names describing what they do
- Keep functions small and focused on one thing
- Separate presentation logic from business logic
- Use verbs for function names: `print_info()`, `build_context()`, `get_exit_code()`
- prefer named functions with docstring over inline comments

## Inline Comment
- Use inline comments to explain external decisions (e.g. numbers decided in jira tickets, historical decision made elsewhere)
- Don't use comment to explain 1-3 line block

## Main
- Keep main() clean and readable - it should read like a high-level description of what the program does
- Move validation and setup into separate functions (e.g., `require_api_key()`, `parse_args()`)
- main() should be read almost like a story in English

## Style
- Prefer single long lines over artificial line breaks
- Remove commented-out code
- Keep the same functionality - don't add or remove features