import { defineI18n } from 'fumadocs-core/i18n';

/**
 * Language definition for Dingit Docs.
 *
 * English is the default — that's the reality of open-source reach
 * (SEO, Hacker News, Product Hunt, GitHub discovery). Chinese is the
 * author's native language and we'd leave real users on the table if
 * we didn't ship it next to en on day one.
 *
 * Both languages carry an explicit prefix — `/en/docs` and `/zh/docs`.
 * Matching the convention of React, Next.js, Vue, and every major i18n
 * docs site, it gives us:
 *   - unambiguous URLs (users see their language)
 *   - SEO-friendly canonical per language
 *   - no Fumadocs middleware rewrite/redirect loop (which bites when
 *     `hideLocale: 'default-locale'` tries to strip the prefix again)
 * Root `/` is redirected to the preferred language via Accept-Language.
 */
export const i18n = defineI18n({
  defaultLanguage: 'en',
  languages: ['en', 'zh'],
  hideLocale: 'never',
});

export type Locale = (typeof i18n.languages)[number];
