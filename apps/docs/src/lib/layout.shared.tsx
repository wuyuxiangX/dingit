import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { defineI18nUI } from 'fumadocs-ui/i18n';
import { BookOpenIcon, TerminalIcon } from 'lucide-react';
import { i18n, type Locale } from './i18n';
import { appName, gitConfig } from './shared';

/**
 * UI translations for the Fumadocs chrome (search bar, theme toggle, TOC,
 * language switcher, etc). English is Fumadocs' default so we only have to
 * fill in Chinese.
 */
export const i18nUI = defineI18nUI(i18n, {
  en: {
    displayName: '🇺🇸 English',
  },
  zh: {
    displayName: '🇨🇳 中文',
    search: '搜索文档',
  },
});

/**
 * Localized nav / footer / sidebar options for the docs chrome.
 *
 * `locale` is the active language (`en` | `zh`). We use it to:
 *   1. Prefix nav URLs with `/zh` when in Chinese (default has no prefix
 *      because of `hideLocale: 'default-locale'` in `i18n.ts`).
 *   2. Localize nav link labels.
 */
export function baseOptions(locale: Locale): BaseLayoutProps {
  const prefix = `/${locale}`;
  const isZh = locale === 'zh';

  return {
    i18n: true,
    nav: {
      url: prefix,
      title: (
        <span className="flex items-center gap-2 font-semibold">
          {/* Plain <img> instead of next/image — SVG skips Next's image
              pipeline (which needs dangerouslyAllowSVG), and at 24x24 the
              optimization gain is zero. */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/dingit-logo.svg"
            alt=""
            width={24}
            height={24}
            className="size-6 rounded-md"
          />
          {appName}
        </span>
      ),
    },
    links: [
      {
        text: isZh ? '文档' : 'Documentation',
        url: `${prefix}/docs`,
        icon: <BookOpenIcon />,
        active: 'nested-url',
      },
      {
        text: 'CLI',
        url: `${prefix}/docs/cli`,
        icon: <TerminalIcon />,
        active: 'nested-url',
      },
    ],
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  };
}
