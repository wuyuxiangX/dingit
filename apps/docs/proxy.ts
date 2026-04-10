import { NextResponse, type NextRequest } from 'next/server';
import { isMarkdownPreferred, rewritePath } from 'fumadocs-core/negotiation';
import { createI18nMiddleware } from 'fumadocs-core/i18n/middleware';
import { i18n } from '@/lib/i18n';
import { docsContentRoute, docsRoute } from '@/lib/shared';

/**
 * Next 16 proxy (formerly middleware) — handles two concerns in order:
 *
 *   1. **Markdown / MDX content negotiation**: when the request is
 *      `/docs/foo.mdx` or carries `Accept: text/markdown`, rewrite to the
 *      raw LLM content route so tools / LLM agents can fetch plain markdown.
 *      This has to run *before* i18n because the rewrite targets
 *      (/llms.mdx/docs/...) live outside the [lang] segment.
 *
 *   2. **i18n locale prefix**: with `hideLocale: 'never'` every URL must
 *      carry `/en` or `/zh`. When the request has no locale prefix the
 *      middleware redirects to the preferred language based on the
 *      Accept-Language header. `/en/docs/foo` and `/zh/docs/foo` pass
 *      through unchanged.
 */

/**
 * Matcher excludes static assets, Next internals, API routes, OG image
 * generation, llms content routes, and metadata files. Without this the
 * proxy also runs against `/_next/static/...`, hanging the page load.
 */
export const config = {
  matcher: [
    '/((?!api|_next/static|_next/image|og|llms|llms\\.mdx|llms\\.txt|llms-full\\.txt|favicon\\.ico|icon\\.png|.*\\.(?:png|jpg|jpeg|gif|svg|webp|ico|css|js|woff2?|ttf|eot)).*)',
  ],
};

const i18nProxy = createI18nMiddleware(i18n);

const { rewrite: rewriteDocs } = rewritePath(
  `${docsRoute}{/*path}`,
  `${docsContentRoute}{/*path}/content.md`,
);
const { rewrite: rewriteSuffix } = rewritePath(
  `${docsRoute}{/*path}.mdx`,
  `${docsContentRoute}{/*path}/content.md`,
);

export default function proxy(
  request: NextRequest,
  ctx: Parameters<ReturnType<typeof createI18nMiddleware>>[1],
) {
  // 1. Suffix rewrite: /docs/foo.mdx -> /llms.mdx/docs/foo/content.md
  const suffixResult = rewriteSuffix(request.nextUrl.pathname);
  if (suffixResult) {
    return NextResponse.rewrite(new URL(suffixResult, request.nextUrl));
  }

  // 2. Accept-header rewrite: curl -H "Accept: text/markdown" /docs/foo
  if (isMarkdownPreferred(request)) {
    const result = rewriteDocs(request.nextUrl.pathname);
    if (result) {
      return NextResponse.rewrite(new URL(result, request.nextUrl));
    }
  }

  // 3. Delegate to Fumadocs i18n middleware for locale prefix handling
  return i18nProxy(request, ctx);
}
