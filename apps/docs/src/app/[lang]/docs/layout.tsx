import { source } from '@/lib/source';
import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import { baseOptions } from '@/lib/layout.shared';
import type { Locale } from '@/lib/i18n';
import { SidebarFooter } from '@/components/sidebar-footer';

export default async function Layout({
  params,
  children,
}: LayoutProps<'/[lang]/docs'>) {
  const { lang } = await params;

  // Strip `links` and `githubUrl` for the docs surface:
  //   - the top nav's Documentation/CLI entries are redundant once the
  //     user is already inside /docs — the sidebar tree carries them
  //   - Fumadocs otherwise replays `links` into the sidebar as "tabs",
  //     which produced the doubled "Documentation / CLI" block next to
  //     the page tree
  //   - we render a custom `SidebarFooter` that packs GitHub + theme +
  //     language into a single row, so the Fumadocs-provided GitHub link
  //     (driven by `githubUrl`) must be stripped to avoid rendering twice.
  // HomeLayout keeps `links` and `githubUrl` so the landing surface still
  // has the nav entry points and GitHub call-to-action.
  const { links: _links, githubUrl: _githubUrl, ...docsOpts } =
    baseOptions(lang as Locale);

  return (
    <DocsLayout
      tree={source.pageTree[lang]}
      tabs={false}
      // Disable the default language/theme slots so Fumadocs doesn't render
      // its own full-width pickers above our custom footer. `SidebarFooter`
      // imports the ThemeSwitch/LanguageSelect components directly, so it
      // still works — we just don't want two copies.
      slots={{
        languageSelect: false,
        themeSwitch: false,
      }}
      sidebar={{ footer: <SidebarFooter lang={lang} /> }}
      {...docsOpts}
    >
      {children}
    </DocsLayout>
  );
}
