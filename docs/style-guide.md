---
hide:
  - navigation
---

# Style Guide

This style guide establishes documentation conventions for the KubeVirt user-guide repository. Following these guidelines ensures consistency, improves readability, and helps both human and AI contributors maintain quality documentation.

## General Writing Principles

- Use clear, direct language
- Active voice preferred over passive voice
- Present tense for describing features ("KubeVirt provides..." not "KubeVirt will provide...")
- Second person for instructions ("You can configure..." not "One can configure...")

## Formatting Conventions

### Headers

- H1 is reserved for the page title (set in frontmatter or first `#` heading)
- Start content sections with H2 (`##`)
- Use sentence case for headers ("Activating feature gates" not "Activating Feature Gates")

### Emphasis (use sparingly)

- **Bold**: Use only for UI elements, field names, or critical warnings
- *Italic*: Avoid in technical documentation - use bold or code formatting instead
- ANTI-PATTERN: Over-using bold and italic reduces their impact and makes docs harder to scan

### Code blocks

Always use fenced code blocks with language specifiers for syntax highlighting:

````markdown
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: example-vm
```
````

**Supported languages:** `yaml`, `bash`, `go`, `json`, `xml`, `console`

**Important:** Do not include shell prompts (`$`, `#`) in command examples - this simplifies copy/paste.

**Correct:**
````markdown
```bash
kubectl apply -f my-vm.yaml
```
````

**Incorrect:**
````markdown
```bash
$ kubectl apply -f my-vm.yaml
```
````

### Inline code

Use backticks for commands, file paths, field names, API objects, and values.

**Examples:**
- Commands: `kubectl`, `virtctl`
- File paths: `/etc/kubevirt/config`
- Field names: `spec.domain.cpu.cores`
- API objects: `VirtualMachine`, `VirtualMachineInstance`
- Values: `true`, `ReadWriteMany`

## Admonitions

Use Material for MkDocs admonition syntax (NOT legacy blockquote or bold patterns).

**Correct syntax:**
```markdown
!!! note
    This is a note without a custom title.

!!! warning "Custom Title"
    This is a warning with a custom title.
```

**Supported admonition types:**

- `note` or `info` - General information, tips, explanations
- `warning` - Important caveats, deprecated features, breaking changes
- `tip` - Helpful suggestions, best practices
- `danger` - Critical warnings about data loss or security

**Standardization:**

- Use lowercase for type (`note`, not `Note` or `NOTE`)
- Be consistent with titles - if you use `"Note"` as a title, use it consistently
- ANTI-PATTERN: `**Note:**` in bold, `> **Note**` in blockquotes - convert these to proper admonitions

## Links

### Internal links

- Use relative paths from the current file location
- Example: `[Installation](../cluster_admin/installation.md)`
- All internal links must resolve - test before submitting

### External links

- Use descriptive link text (not "click here")
- Prefer official documentation sources
- Example: `[Kubernetes feature gates](https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/)`

## Navigation and File Management

### Adding a new file

1. Create the markdown file in the appropriate directory
2. Add an entry to the `.nav.yml` file in the same directory
3. Do NOT add a redirect in `mkdocs.yml` (only needed for renamed/moved files)

### Renaming or moving an existing file

1. Rename/move the file
2. Update the corresponding `.nav.yml` file
3. Add a redirect mapping in `mkdocs.yml` under `plugins.redirects.redirect_maps`
4. Format: `'old/path.md': 'new/path.md'`

### Navigation hierarchy

- Navigation is controlled by `.nav.yml` files, not `mkdocs.yml`
- Each directory can have its own `.nav.yml`
- Keep navigation depth reasonable (2-3 levels max)

## Tables

Use standard Markdown table syntax:

```markdown
| Feature | Status | Version |
|---------|--------|---------|
| CPU hotplug | GA | v1.1 |
| Memory hotplug | Beta | v1.2 |
```

- Align columns for readability in source
- Include header row

## Lists

### Unordered lists

- Use `-` for consistency (not `*` or `+`)
- Indent nested items with 2 spaces

### Ordered lists

- Use `1.`, `2.`, `3.` etc.
- Markdown will auto-number, but explicit numbers improve source readability

## Material for MkDocs Extensions

This site uses Material for MkDocs. Refer to the [Material reference](https://squidfunk.github.io/mkdocs-material/reference/) for:

- [Admonitions](https://squidfunk.github.io/mkdocs-material/reference/admonitions/)
- [Code blocks](https://squidfunk.github.io/mkdocs-material/reference/code-blocks/)
- [Content tabs](https://squidfunk.github.io/mkdocs-material/reference/content-tabs/)
- Other advanced features

Use these extensions when they improve clarity, but don't add complexity unnecessarily.

## Review Checklist

Before submitting documentation changes:

- [ ] Page renders correctly at the expected URL path
- [ ] All internal links resolve (click through each one)
- [ ] Tables and code blocks render properly
- [ ] No MkDocs build warnings
- [ ] Admonitions use correct Material syntax (not legacy bold/blockquote)
- [ ] Navigation changes reflected in appropriate `.nav.yml`
- [ ] Redirects added if files were renamed/moved
- [ ] Existing pages not broken by navigation changes
- [ ] Spelling and grammar checked
- [ ] Code examples tested (if applicable)
