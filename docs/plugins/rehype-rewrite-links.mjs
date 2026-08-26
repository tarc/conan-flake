// Rewrites the relative `*.md` links the Markdown sources use into the page
// URLs the built site serves.
//
// The sources link to each other the way a repository browser expects
// (`[Toolchains](./toolchains.md)`), which keeps every cross-reference
// clickable while reading the sources on Codeberg. Astro does not transform
// Markdown link targets, so without this the built page would carry
// `href="./toolchains.md"` and 404. Each such href becomes
// `<base>/<slug>/`, with `./index.md` pointing at the site root and any
// `#anchor` preserved.
//
// It has to be a *rehype* plugin: Starlight replaces `markdown.remarkPlugins`
// while it configures Astro, so a remark plugin declared here would be
// dropped.
//
// site.NAVIGATION.3
// site.GUIDES.1

// `./getting-started.md`, `../toolchains.md#stdenv`, `index.md` — a relative
// path with no directory component other than `./` or `../`, which is the only
// shape the site's sources use.
const markdownLink = /^(?:\.{1,2}\/)?([\w.-]+)\.md(#.*)?$/;

const visit = (node, onElement) => {
  if (node.type === "element") {
    onElement(node);
  }

  for (const child of node.children ?? []) {
    visit(child, onElement);
  }
};

/**
 * @param {{ base?: string }} options
 */
export default function rehypeRewriteLinks(options = {}) {
  // A base of `/conan-flake` yields `/conan-flake/<slug>/`; a base of `/`
  // yields `/<slug>/`.
  const base = `${(options.base ?? "/").replace(/\/+$/, "")}/`;

  return (tree) => {
    visit(tree, (element) => {
      if (element.tagName !== "a") return;

      const href = element.properties?.href;
      if (typeof href !== "string") return;

      const match = markdownLink.exec(href);
      if (match === null) return;

      const [, name, anchor = ""] = match;

      element.properties.href =
        name === "index" ? `${base}${anchor}` : `${base}${name}/${anchor}`;
    });
  };
}
