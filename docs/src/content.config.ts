// The Markdown sources of the site live under a single directory, tracked in
// git: `src/content/docs`, which is where Starlight's loader reads them from.
//
// site.SOURCES.1
import { defineCollection } from "astro:content";
import { docsLoader } from "@astrojs/starlight/loaders";
import { docsSchema } from "@astrojs/starlight/schema";

export const collections = {
  docs: defineCollection({ loader: docsLoader(), schema: docsSchema() }),
};
