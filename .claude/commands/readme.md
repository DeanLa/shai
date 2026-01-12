Update README.md based on the latest changes in this conversation.

Review the current conversation and identify changes that should be reflected in the README.

## Writing Style - Stacked Excitement

Structure the README to hook readers progressively:

1. **Lead with the magic** - The basic `shai "..."` → command appears in your buffer ready to run. This alone excites 90% of people. Show it immediately.

2. **Then reveal depth** - Flags, options, customization. For users who want more control.

3. **Then advanced features** - Memory, context, integrations. For power users who are now invested. Be thorough with environment variables - explain each one, what it does, and example values.

Build excitement layer by layer. Don't front-load complexity.

## Planned Features

Keep these in the README as "coming soon" until implemented:
- Multi-provider support (Anthropic, Gemini, local models) - currently OpenAI only
- Full multi-shell support (bash, fish) - currently zsh only. "Full" means buffer pre-loading, keybinding widget, session tracking - not just basic command execution. Install script will auto-detect shell.

## Do NOT:
- Remove existing valid documentation
- Remove or overwrite images, videos, or GIFs - these are manually added
- Remove "coming soon" notes for planned features unless they're implemented
- Add implementation details that belong in code comments
- Include temporary or experimental features (unless marked as planned)
- Write dry, technical-first documentation
- Bury the exciting UX under setup instructions