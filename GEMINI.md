# GEMINI.md - Instructional Context for ilmanzo.github.com

This file provides comprehensive guidelines, architectural mapping, and operational procedures for maintaining and developing the **ilmanzo.github.com** personal blog.

---

## 📖 Project Overview

This is the personal website and technical portfolio of **Andrea Manzini** (Unix System Administrator, QE Automation Engineer, and open-source developer). It is a minimalist, content-focused static blog built using **Hugo** (extended edition) and styled with the popular **PaperMod** theme.

### Core Stack
* **SSG:** Hugo (YAML-based configuration)
* **Theme:** [PaperMod](https://github.com/adityatelgote/hugo-PaperMod) (embedded as a Git submodule in `themes/PaperMod`)
* **Styling:** Custom CSS extensions housed in `assets/css/extended/`
* **Deployment:** GitHub Pages (automatically built and deployed via GitHub Actions)

---

## 📂 Key Directory Structure

```text
/home/andrea/projects/ilmanzo.github.com/
├── hugo.yaml               # Main Hugo configuration file
├── content/                # All site content (Markdown, multilingual)
│   ├── en/                 # English content directory (default language)
│   │   ├── post/           # English blog posts
│   │   ├── archives.md     # English archives index
│   │   ├── curriculum.md   # English curriculum vitae
│   │   ├── search.md       # English search page
│   │   └── _index.md_1     # Homepage backup file
│   └── it/                 # Italian content directory (dynamically served under /it/)
│       ├── post/           # Translated Italian blog posts (last 20 posts in IT)
│       ├── archives.md     # Italian archives index (translated)
│       ├── curriculum.md   # Italian curriculum vitae (translated to Italian)
│       └── search.md       # Italian search page (translated)
├── archetypes/             # Templates for new content creation
│   └── default.md          # Front matter template for new posts
├── assets/
│   └── css/extended/       # Custom CSS overrides for PaperMod
├── static/                 # Static assets (images, PDFs, downloadable files)
│   ├── files/              # PDF resumes, slide links, sample code
│   └── img/                # Post images, screenshots, diagrams, and gifs
└── themes/                 # Embedded themes and theme-related scripts
    ├── PaperMod/           # Git submodule for the theme
    ├── reduce_photos.sh    # Script to optimize images before upload
    └── update-themes.sh    # Script to update theme submodules
```

---

## 🛠️ Key Commands & Workflows

### Running & Testing Locally
To run the blog locally with a live-reloading server:
```bash
# Run local development server
hugo server

# Run local development server including draft posts
hugo server -D
```

### Building the Site
```bash
# Build the production site (minified static files are generated in ./public)
hugo --minify
```

### Content Creation & Archetypes
When creating a new blog post, use Hugo's generator to ensure correct front matter template adoption:
```bash
hugo new post/my-new-post.md
```
The resulting file is initialized based on `archetypes/default.md`.

### Image Optimization
Before committing newly added images to `static/img/`, run the helper utility to reduce their file sizes:
```bash
cd themes/
./reduce_photos.sh   # Resizes all *.jpg images in the directory to 50% width
```

### Updating Submodules
To pull the latest changes for the Hugo PaperMod theme:
```bash
./themes/update-themes.sh  # Runs git submodule update --remote --merge
```

---

## ✍️ Content & Writing Conventions

All blog posts are authored in Markdown.
* **English (Default):** Reside under `content/en/post/`
* **Italian:** Reside under `content/it/post/` with the exact same filename.

### Front Matter Format
Every post must contain YAML front matter. Example:

```yaml
---
layout: post
title: "a honeypot ssh server in Go"
description: "a fake ssh server that works as a honeypot, written in Go"
categories: programming
tags: [go, golang, programming, ssh, linux, hacking]
author: Andrea Manzini
date: 2018-06-26
---
```

### Multilingual & Translation Rules
1. **Configuring contentDir:** Under `hugo.yaml`, the `languages` block explicitly links each language to its distinct content directory path using the `contentDir` attribute:
   ```yaml
   languages:
     en:
       label: English
       locale: en-US
       contentDir: content/en
     it:
       label: Italiano
       locale: it-IT
       contentDir: content/it
   ```
2. **Translation Consistency:** When translating posts to Italian:
   * Maintain the exact same filename.
   * Translate the front matter `title` and `description` to Italian, but keep original keys and dates. Keep standard technical tags or translate general category/tag labels (e.g. `programming` -> `programmazione`).
   * Do not translate code blocks, configurations, shell commands, or standard technical terminology (e.g. *rootless*, *socket activation*, *kernel*, *sandboxing*, etc.).
   * Retain the exact same images, absolute links, and Hugo shortcodes.
3. **Summary Excerpt:** Always include the `<!--more-->` separator tag inside the post body to define the summary text shown on list pages.
4. **Code Highlighting:** Use standard markdown fences with language tags or Hugo's built-in shortcode helper:
   `{{< highlight go >}} ... {{< /highlight >}}`
5. **Tone & Style:** Maintain a highly technical, minimalist, pragmatic, and hands-on tone. Focus on system administration, performance, benchmarks, scripting, automation, containerization, and systems programming languages (Rust, Go, D, Crystal, Nim, Python).

---

## 🚀 Deployment Pipeline

The site is built and deployed automatically via a GitHub Actions workflow defined in `.github/workflows/gh-pages.yml`.

* **Triggers:** Push to the `master` branch.
* **Build Action:** Installs the extended version of Hugo and runs `hugo --minify`.
* **Deployment Destination:** Static files from `./public` are deployed directly to the `gh-pages` branch for hosting on `https://ilmanzo.github.io/`.
