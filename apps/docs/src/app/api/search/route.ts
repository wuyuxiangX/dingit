import { source } from '@/lib/source';
import { createFromSource } from 'fumadocs-core/search/server';

/**
 * Search API — localeMap pins both `en` and `zh` to Orama's `english`
 * tokenizer. Orama doesn't ship a first-party CJK tokenizer on the server
 * path (see https://docs.orama.com/docs/orama-js/supported-languages), so
 * Chinese search is ASCII-word-matched for now. TODO: when it matters,
 * wire `@orama/tokenizers/mandarin` into the client-side static path.
 */
export const { GET } = createFromSource(source, {
  localeMap: {
    en: { language: 'english' },
    zh: { language: 'english' },
  },
});
