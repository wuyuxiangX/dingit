'use client';

import type { SVGProps } from 'react';
import { ThemeSwitch } from 'fumadocs-ui/layouts/shared/slots/theme-switch';
import { LanguageSelect } from 'fumadocs-ui/layouts/shared/slots/language-select';
import { gitConfig } from '@/lib/shared';

// GitHub mark inlined because lucide-react 1.x dropped brand icons. Path
// is the public GitHub mark SVG — no license constraint on rendering.
function GithubMark(props: SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden {...props}>
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
    </svg>
  );
}

/**
 * Sidebar footer — single row containing GitHub / theme / language.
 *
 * Fumadocs' default footer stacks the language picker above the GitHub +
 * theme toggle row, eating vertical space and looking disconnected. Here
 * we collapse all three into one horizontal control strip, with the
 * language picker reduced to an icon-only button showing just the current
 * country flag. The full locale names live in the popover menu.
 *
 * `lang` is passed in from the Server Component layout so we don't have to
 * plumb Next.js' `useParams` through yet another client hook.
 */

const FLAGS: Record<string, string> = {
  en: '🇺🇸',
  zh: '🇨🇳',
};

export function SidebarFooter({ lang }: { lang: string }) {
  const flag = FLAGS[lang] ?? '🌐';

  return (
    <div className="flex items-center gap-1 border-t border-fd-border px-2 py-2">
      <a
        href={`https://github.com/${gitConfig.user}/${gitConfig.repo}`}
        target="_blank"
        rel="noreferrer"
        aria-label="GitHub"
        className="inline-flex size-8 items-center justify-center rounded-md text-fd-muted-foreground transition-colors hover:bg-fd-accent hover:text-fd-accent-foreground"
      >
        <GithubMark className="size-4" />
      </a>
      <div className="ml-auto flex items-center gap-1">
        <ThemeSwitch />
        <LanguageSelect
          aria-label="Choose a language"
          className="inline-flex size-8 items-center justify-center rounded-md text-base leading-none"
        >
          <span aria-hidden>{flag}</span>
        </LanguageSelect>
      </div>
    </div>
  );
}
