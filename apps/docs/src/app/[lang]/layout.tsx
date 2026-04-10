import type { Metadata } from 'next';
import { RootProvider } from 'fumadocs-ui/provider/next';
import { DM_Serif_Display, Plus_Jakarta_Sans } from 'next/font/google';
import { i18nUI } from '@/lib/layout.shared';
import type { Locale } from '@/lib/i18n';
import '../global.css';

export const metadata: Metadata = {
  metadataBase: new URL('https://docs.dingit.me'),
  title: {
    template: '%s · Dingit Docs',
    default: 'Dingit Docs · Self-hosted interactive notifications',
  },
  description:
    'Dingit turns scripts, servers, and CI jobs into interactive notifications — delivered to App, CLI, and Server in real time.',
};

// Editorial display serif — matches apps/app DM Serif Display for headings.
const display = DM_Serif_Display({
  subsets: ['latin'],
  weight: '400',
  variable: '--font-display',
  display: 'swap',
});

// Clean, highly legible body sans — matches apps/app Plus Jakarta Sans.
const sans = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
});

export default async function Layout({
  params,
  children,
}: LayoutProps<'/[lang]'>) {
  const { lang } = await params;
  // Map our internal locale codes to BCP 47 HTML lang attribute values.
  // Keeping the internal code short (`zh`) is friendlier for URLs and
  // source files, but `<html lang>` should carry the region per BCP 47.
  const htmlLang = lang === 'zh' ? 'zh-CN' : 'en';

  return (
    <html
      lang={htmlLang}
      className={`${display.variable} ${sans.variable}`}
      suppressHydrationWarning
    >
      <body className="flex flex-col min-h-screen font-sans antialiased">
        <RootProvider i18n={i18nUI.provider(lang as Locale)}>
          {children}
        </RootProvider>
      </body>
    </html>
  );
}
